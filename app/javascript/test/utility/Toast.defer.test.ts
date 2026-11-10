import { beforeEach, describe, expect, it, vi } from "vitest";

const KEY = "e6.toast.pending";
const MESSAGE = "Added post to <a href=\"/post_sets/8\">set #8</a>";

async function loadToast () {
  vi.resetModules();
  return (await import("@/utility/Toast")).default;
}

describe("ToastManager.defer", () => {
  beforeEach(() => {
    sessionStorage.clear();
    document.body.innerHTML = "<div id=\"toast-container\"></div>";
  });

  it("stores the message for the next page load", async () => {
    const ToastManager = await loadToast();
    ToastManager.defer(MESSAGE);

    expect(sessionStorage.getItem(KEY)).toBe(MESSAGE);
    expect(ToastManager.get(MESSAGE)).toBeNull();
  });

  it("shows the pending message as a notice on bootstrap and clears it", async () => {
    sessionStorage.setItem(KEY, MESSAGE);
    const ToastManager = await loadToast();
    ToastManager.bootstrap();

    expect(ToastManager.get(MESSAGE)?.type).toBe("notice");
    expect(sessionStorage.getItem(KEY)).toBeNull();
  });

  it("shows the message only once", async () => {
    sessionStorage.setItem(KEY, MESSAGE);
    (await loadToast()).bootstrap();

    const ToastManager = await loadToast();
    ToastManager.bootstrap();
    expect(ToastManager.get(MESSAGE)).toBeNull();
  });

  it("creates no toast when nothing is pending", async () => {
    const ToastManager = await loadToast();
    ToastManager.bootstrap();

    expect(document.querySelectorAll("#toast-container .toast")).toHaveLength(0);
  });
});
