import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

async function loadToast () {
  vi.resetModules();
  return (await import("@/utility/Toast")).default;
}

describe("ToastManager.track", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    document.body.innerHTML = "";
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("shows the pending message, then rewrites it on success", async () => {
    const ToastManager = await loadToast();
    let resolve!: (value: number) => void;
    const promise = new Promise<number>((r) => { resolve = r; });

    const tracked = ToastManager.track(promise, "Updating post...", (n) => `Done ${n}`);
    const toast = ToastManager.get("Updating post...");
    expect(toast).not.toBeNull();
    expect(toast!.type).toBe("info");

    resolve(5);
    await expect(tracked).resolves.toBe(5);
    expect(toast!.message).toBe("Done 5");
    expect(toast!.type).toBe("notice");
    expect(toast!.timeout).toBe(1);
  });

  it("dismisses the toast and resolves with undefined on failure", async () => {
    const ToastManager = await loadToast();
    const tracked = ToastManager.track(Promise.reject(undefined), "Updating post...", () => "never");

    await expect(tracked).resolves.toBeUndefined();
    expect(ToastManager.get("Updating post...")).toBeNull();
  });
});
