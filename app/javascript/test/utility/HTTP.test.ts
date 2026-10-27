import { describe, expect, it, vi } from "vitest";
import { htmlResponse, jsonResponse, setMeta } from "../helpers";

async function freshHTTP () {
  return (await import("@/utility/HTTP")).default;
}

describe("HTTP", () => {
  it("serializes params into a query string, skipping undefined/null", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue({} as Response);
    const HTTP = await freshHTTP();
    await HTTP.get("/x", { a: 1, b: "two", c: undefined, d: null });
    expect(fetchSpy.mock.calls[0][0]).toBe("/x?a=1&b=two");
  });

  it("omits the query string when there are no params", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue({} as Response);
    const HTTP = await freshHTTP();
    await HTTP.get("/x");
    expect(fetchSpy.mock.calls[0][0]).toBe("/x");
  });

  it("adds the CSRF token + credentials on POST but not GET", async () => {
    setMeta("csrf-token", "tok123");
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue({} as Response);
    const HTTP = await freshHTTP();

    await HTTP.post("/x", new URLSearchParams({ a: "1" }));
    const postInit = fetchSpy.mock.calls[0][1] as RequestInit;
    expect((postInit.headers as Record<string, string>)["X-CSRF-Token"]).toBe("tok123");
    expect(postInit.credentials).toBe("same-origin");

    await HTTP.get("/y");
    const getInit = fetchSpy.mock.calls[1][1] as RequestInit;
    expect((getInit.headers as Record<string, string>)["X-CSRF-Token"]).toBeUndefined();
  });

  it("getJSON rejects on a non-2xx response even when the body is valid JSON", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ error: "boom" }, { status: 500 }) as Response);
    const HTTP = await freshHTTP();
    await expect(HTTP.getJSON("/x")).rejects.toThrow();
  });

  describe("errorMessage", () => {
    it("prefers message, then reason", async () => {
      const HTTP = await freshHTTP();
      expect(await HTTP.errorMessage(jsonResponse({ message: "Too many", reason: "x" }, { status: 422 }))).toBe("Too many");
      expect(await HTTP.errorMessage(jsonResponse({ success: false, reason: "Access denied" }, { status: 403 }))).toBe("Access denied");
    });

    it("joins an errors array or an attribute hash", async () => {
      const HTTP = await freshHTTP();
      expect(await HTTP.errorMessage(jsonResponse({ errors: ["a", "b"] }, { status: 422 }))).toBe("a; b");
      expect(await HTTP.errorMessage(jsonResponse({ errors: { base: ["a"], name: ["b", "c"] } }, { status: 422 }))).toBe("a; b; c");
    });

    it("maps a bodyless 404 to Not Found", async () => {
      const HTTP = await freshHTTP();
      expect(await HTTP.errorMessage(htmlResponse(404))).toBe("Not Found");
      expect(await HTTP.errorMessage(jsonResponse({}, { status: 404 }))).toBe("Not Found");
    });

    it("falls back to the status line or the given fallback for non-JSON bodies", async () => {
      const HTTP = await freshHTTP();
      expect(await HTTP.errorMessage({ ...htmlResponse(502), statusText: "Bad Gateway" })).toBe("502 Bad Gateway");
      expect(await HTTP.errorMessage(htmlResponse(502), "Upstream down")).toBe("Upstream down");
    });
  });
});
