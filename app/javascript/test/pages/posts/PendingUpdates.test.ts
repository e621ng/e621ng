import { beforeEach, describe, expect, it, vi } from "vitest";

type Recorder = { message: string, timeout: number };
const toasts: Recorder[] = [];
const toast = {
  create: vi.fn((message: string, options: { timeout?: number } = {}) => {
    const recorder = { message, timeout: options.timeout ?? 3 };
    toasts.push(recorder);
    return recorder;
  }),
  dismiss: vi.fn(),
};
vi.mock("@/utility/Toast", () => ({ default: toast }));

async function load () {
  return (await import("@/pages/posts/PendingUpdates")).default;
}

describe("PendingUpdates", () => {
  beforeEach(() => {
    toasts.length = 0;
    toast.create.mockClear();
    toast.dismiss.mockClear();
  });

  it("creates a permanent toast on the first pending update", async () => {
    const PendingUpdates = await load();

    PendingUpdates.begin();

    expect(toast.create).toHaveBeenCalledWith("Updating posts...", { timeout: 0 });
    expect(toast.dismiss).toHaveBeenCalledWith("Posts updated");
    expect(toasts[0].message).toBe("Updating posts (1 pending)...");
    expect(PendingUpdates.count).toBe(1);
  });

  it("reuses the toast while updates are pending", async () => {
    const PendingUpdates = await load();

    PendingUpdates.begin();
    PendingUpdates.begin();
    expect(toast.create).toHaveBeenCalledTimes(1);
    expect(toasts[0].message).toBe("Updating posts (2 pending)...");

    PendingUpdates.end();
    expect(toasts[0].message).toBe("Updating posts (1 pending)...");
    expect(toasts[0].timeout).toBe(0);
  });

  it("announces completion and starts over on the next update", async () => {
    const PendingUpdates = await load();

    PendingUpdates.begin();
    PendingUpdates.end();
    expect(toasts[0]).toEqual({ message: "Posts updated", timeout: 3 });
    expect(PendingUpdates.count).toBe(0);

    PendingUpdates.begin();
    expect(toast.create).toHaveBeenCalledTimes(2);
    expect(toasts[1].message).toBe("Updating posts (1 pending)...");
  });

  it("never counts below zero", async () => {
    const PendingUpdates = await load();

    PendingUpdates.end();

    expect(PendingUpdates.count).toBe(0);
    expect(toasts[0].message).toBe("Posts updated");
  });

  describe("track", () => {
    it("passes the resolved value through and balances the count", async () => {
      const PendingUpdates = await load();

      await expect(PendingUpdates.track(Promise.resolve(42))).resolves.toBe(42);
      expect(PendingUpdates.count).toBe(0);
      expect(toasts[0].message).toBe("Posts updated");
    });

    it("passes a rejection through and still balances the count", async () => {
      const PendingUpdates = await load();

      await expect(PendingUpdates.track(Promise.reject(new Error("nope")))).rejects.toThrow("nope");
      expect(PendingUpdates.count).toBe(0);
    });

    it("counts concurrent operations", async () => {
      const PendingUpdates = await load();
      let resolveA: () => void, resolveB: () => void;
      const a = PendingUpdates.track(new Promise<void>((resolve) => { resolveA = resolve; }));
      const b = PendingUpdates.track(new Promise<void>((resolve) => { resolveB = resolve; }));
      expect(toasts[0].message).toBe("Updating posts (2 pending)...");

      resolveA();
      await a;
      expect(toasts[0].message).toBe("Updating posts (1 pending)...");

      resolveB();
      await b;
      expect(toasts[0].message).toBe("Posts updated");
    });
  });
});
