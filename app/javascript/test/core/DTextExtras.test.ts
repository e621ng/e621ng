import { beforeEach, describe, expect, it, vi } from "vitest";

const writeText = vi.fn<(text: string) => Promise<void>>();

function stubClipboard (supported = true) {
  vi.stubGlobal("navigator", { ...navigator, clipboard: supported ? { writeText } : undefined });
}

function render () {
  document.body.innerHTML = `
    <div class="dtext-container"><pre>line one
line two</pre></div>
    <pre id="outside">not dtext</pre>`;
}

async function load () {
  const ToastManager = (await import("@/utility/Toast")).default;
  vi.spyOn(ToastManager, "create").mockReturnValue({} as never);
  await import("@/core/DTextExtras");
}

const settle = () => new Promise((resolve) => setTimeout(resolve, 0));

describe("DTextExtras code blocks", () => {
  beforeEach(() => {
    writeText.mockReset().mockResolvedValue(undefined);
    stubClipboard();
    render();
  });

  it("adds a copy button to DText code blocks only", async () => {
    await load();
    expect(document.querySelectorAll(".dtext-container pre > .copy-button")).toHaveLength(1);
    expect(document.querySelector("#outside .copy-button")).toBeNull();
  });

  it("copies the code without the button", async () => {
    await load();
    (document.querySelector(".dtext-container .copy-button") as HTMLButtonElement).click();
    await settle();

    expect(writeText).toHaveBeenCalledWith("line one\nline two");
  });

  it("adds no buttons without clipboard support", async () => {
    stubClipboard(false);
    await load();
    expect(document.querySelector(".copy-button")).toBeNull();
  });
});
