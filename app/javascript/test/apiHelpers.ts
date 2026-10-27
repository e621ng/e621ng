import { vi } from "vitest";
import { setMeta } from "./helpers";

/** Shared scaffolding for specs of the ApiRequest-based models. */

/** Seeds the CSRF token, silences console.error, and spies on fetch with the given response. */
export function stubFetch (response: unknown): ReturnType<typeof vi.spyOn> {
  setMeta("csrf-token", "tok123");
  vi.spyOn(console, "error").mockImplementation(() => {});
  return vi.spyOn(globalThis, "fetch").mockResolvedValue(response as Response);
}

/** Runs queued tasks immediately; the returned spy exposes the queue options passed. */
export async function bypassQueue () {
  const { default: TaskQueue } = await import("@/utility/TaskQueue");
  return vi.spyOn(TaskQueue, "add").mockImplementation((task) => Promise.resolve().then(task));
}

/** Collects every `danbooru:error` message triggered on window. Call `$(window).off` in afterEach. */
export function recordErrors (): string[] {
  const seen: string[] = [];
  $(window).on("danbooru:error", (_e, message: string) => { seen.push(message); });
  return seen;
}

/** The URL and init of the most recent fetch call. */
export function lastFetch (spy: { mock: { calls: unknown[][] } }): { url: string, init: RequestInit } {
  const call = spy.mock.calls[spy.mock.calls.length - 1] as [string, RequestInit];
  return { url: call[0], init: call[1] };
}
