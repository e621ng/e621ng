import { describe, expect, it, vi } from "vitest";
import { jsonResponse, setMeta } from "../helpers";

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
    expect(postInit.credentials).toBe("include");

    await HTTP.get("/y");
    const getInit = fetchSpy.mock.calls[1][1] as RequestInit;
    expect((getInit.headers as Record<string, string>)["X-CSRF-Token"]).toBeUndefined();
  });

  it("getJSON rejects on a non-2xx response even when the body is valid JSON", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ error: "boom" }, { status: 500 }) as Response);
    const HTTP = await freshHTTP();
    await expect(HTTP.getJSON("/x")).rejects.toThrow();
  });
});
