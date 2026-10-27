import { afterEach, describe, expect, it, vi } from "vitest";
import { bypassQueue, lastFetch, recordErrors, stubFetch } from "../apiHelpers";
import { htmlResponse, jsonResponse } from "../helpers";

async function freshApi () {
  const mod = await import("@/utility/ApiRequest");
  return { ApiRequest: mod.default, ApiError: mod.ApiError };
}

describe("ApiRequest", () => {
  afterEach(() => { $(window).off("danbooru:error"); });

  describe("send", () => {
    it("serializes a JSON body with the content type and CSRF headers", async () => {
      const fetchSpy = stubFetch(jsonResponse({}));
      const { ApiRequest } = await freshApi();

      const response = await ApiRequest.send("/things.json", { method: "POST", json: { a: 1 } });

      expect(response.ok).toBe(true);
      const { url, init } = lastFetch(fetchSpy);
      expect(url).toBe("/things.json");
      expect(init.method).toBe("POST");
      expect(init.body).toBe(JSON.stringify({ a: 1 }));
      expect(init.credentials).toBe("same-origin");
      expect(init.headers).toEqual({ "Content-Type": "application/json", "X-CSRF-Token": "tok123" });
    });

    it("sends no body or content type when json is absent, and merges extra headers and params", async () => {
      const fetchSpy = stubFetch(jsonResponse({}));
      const { ApiRequest } = await freshApi();

      await ApiRequest.send("/things.json", { method: "POST", headers: { Accept: "text/plain" }, params: { q: "x" } });

      const { url, init } = lastFetch(fetchSpy);
      expect(url).toBe("/things.json?q=x");
      expect(init.body).toBeUndefined();
      expect(init.headers).toEqual({ "Accept": "text/plain", "X-CSRF-Token": "tok123" });
    });

    it("schedules through TaskQueue when queue options are given", async () => {
      stubFetch(jsonResponse({}));
      const queue = await bypassQueue();
      const { ApiRequest } = await freshApi();

      await ApiRequest.send("/things.json", { queue: { name: "Thing.send", unique: true, delay: 750 } });

      expect(queue).toHaveBeenCalledTimes(1);
      expect(queue.mock.calls[0][1]).toEqual({ name: "Thing.send", unique: true, delay: 750 });
    });

    it("bypasses TaskQueue when no queue options are given", async () => {
      stubFetch(jsonResponse({}));
      const queue = await bypassQueue();
      const { ApiRequest } = await freshApi();

      await ApiRequest.send("/things.json");

      expect(queue).not.toHaveBeenCalled();
    });

    it("resolves a 204 without touching the body", async () => {
      const response = jsonResponse(null, { status: 204 });
      response.json = vi.fn();
      stubFetch(response);
      const { ApiRequest } = await freshApi();

      await expect(ApiRequest.send("/things.json", { method: "DELETE" })).resolves.toBe(response);
      expect(response.json).not.toHaveBeenCalled();
    });

    it.each([
      ["responders errors hash", { errors: { reason: ["can't be blank"] } }, 422, "can't be blank"],
      ["expected error message", { success: false, message: "Nope" }, 403, "Nope"],
      ["reason", { reason: "Already done" }, 409, "Already done"],
    ])("rejects with an ApiError and reports the %s", async (_label, body, status, message) => {
      stubFetch(jsonResponse(body, { status }));
      const { ApiRequest, ApiError } = await freshApi();
      const errors = recordErrors();

      const error = await ApiRequest.send("/things.json").catch((e) => e);

      expect(error).toBeInstanceOf(ApiError);
      expect(error.status).toBe(status);
      expect(error.message).toBe(message);
      expect(errors).toEqual(["Error: " + message]);
    });

    it("falls back to the status line for non-JSON failures", async () => {
      stubFetch(htmlResponse(429));
      const { ApiRequest } = await freshApi();
      const errors = recordErrors();

      await expect(ApiRequest.send("/things.json")).rejects.toMatchObject({ status: 429, message: "429" });
      expect(errors).toEqual(["Error: 429"]);
    });

    it("uses errorText for backend failures only", async () => {
      stubFetch(jsonResponse({ reason: "not found" }, { status: 404 }));
      const { ApiRequest } = await freshApi();
      const errors = recordErrors();
      const errorText = vi.fn(() => "Custom text");

      await expect(ApiRequest.send("/things.json", { errorText })).rejects.toMatchObject({ status: 404 });

      expect(errorText).toHaveBeenCalledTimes(1);
      expect(errors).toEqual(["Custom text"]);
    });

    it("reports and rethrows network failures", async () => {
      stubFetch(jsonResponse({})).mockRejectedValue(new TypeError("Failed to fetch"));
      const { ApiRequest } = await freshApi();
      const errors = recordErrors();
      const errorText = vi.fn(() => "Custom text");

      await expect(ApiRequest.send("/things.json", { errorText })).rejects.toThrow("Failed to fetch");

      expect(errorText).not.toHaveBeenCalled();
      expect(errors).toEqual(["Error: Failed to fetch"]);
      expect(console.error).toHaveBeenCalled();
    });

    it("passes a TaskCancelled through silently", async () => {
      stubFetch(jsonResponse({}));
      const { default: TaskQueue, TaskCancelled } = await import("@/utility/TaskQueue");
      vi.spyOn(TaskQueue, "add").mockImplementation(() => Promise.reject(new TaskCancelled("Replaced")));
      const { ApiRequest } = await freshApi();
      const errors = recordErrors();

      const error = await ApiRequest.send("/things.json", { queue: { name: "x" } }).catch((e) => e);

      expect(error).toBeInstanceOf(TaskCancelled);
      expect(errors).toEqual([]);
      expect(console.error).not.toHaveBeenCalled();
    });
  });

  describe("json", () => {
    it("parses the body of an ok response", async () => {
      stubFetch(jsonResponse({ id: 7 }));
      const { ApiRequest } = await freshApi();

      await expect(ApiRequest.json("/things/7.json")).resolves.toEqual({ id: 7 });
    });

    it("reports and rethrows a parse failure on an ok response", async () => {
      stubFetch(htmlResponse(200));
      const { ApiRequest } = await freshApi();
      const errors = recordErrors();

      await expect(ApiRequest.json("/things/7.json")).rejects.toBeInstanceOf(SyntaxError);
      expect(errors).toEqual(["Error: Unexpected token '<'"]);
    });

    it("rejects with the ApiError of a failed response", async () => {
      stubFetch(jsonResponse({ message: "Nope" }, { status: 403 }));
      const { ApiRequest, ApiError } = await freshApi();
      recordErrors();

      await expect(ApiRequest.json("/things/7.json")).rejects.toBeInstanceOf(ApiError);
    });
  });
});
