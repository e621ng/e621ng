import { beforeEach, describe, expect, it, vi } from "vitest";

const writeText = vi.fn<(text: string) => Promise<void>>();

function stubClipboard (supported = true) {
  vi.stubGlobal("navigator", { ...navigator, clipboard: supported ? { writeText } : undefined });
}

// Toast is re-imported after the reset so spies land on the instance the module uses.
async function load () {
  const ToastManager = (await import("@/utility/Toast")).default;
  const create = vi.spyOn(ToastManager, "create").mockReturnValue({} as never);
  const alert = vi.spyOn(ToastManager, "alert").mockReturnValue(undefined);
  const CopyButton = (await import("@/core/CopyButton")).default;
  return { CopyButton, create, alert };
}

function renderButton (attrs: string) {
  document.body.insertAdjacentHTML("beforeend", `<button type="button" class="copy-button" ${attrs}><svg></svg></button>`);
  return document.body.lastElementChild as HTMLButtonElement;
}

// Click handlers kick off an async copy; let it settle
const settle = () => new Promise((resolve) => setTimeout(resolve, 0));

describe("CopyButton", () => {
  beforeEach(() => {
    writeText.mockReset().mockResolvedValue(undefined);
    document.documentElement.className = "";
    stubClipboard();
  });

  describe("clipboard support flag", () => {
    it("is set on <html> when the Clipboard API exists", async () => {
      await load();
      expect(document.documentElement.classList.contains("clipboard-supported")).toBe(true);
    });

    it("is not set when the Clipboard API is missing", async () => {
      stubClipboard(false);
      await load();
      expect(document.documentElement.classList.contains("clipboard-supported")).toBe(false);
    });
  });

  describe("server-rendered buttons", () => {
    it("copies data-copy-text and confirms", async () => {
      const { create } = await load();
      renderButton("data-copy-text='some_user' data-copy-label='username'").click();
      await settle();

      expect(writeText).toHaveBeenCalledWith("some_user");
      expect(create).toHaveBeenCalledWith("Copied to clipboard!", { timeout: 1 });
    });

    it("reports failures using the label", async () => {
      writeText.mockRejectedValue(new Error("denied"));
      const { alert } = await load();
      renderButton("data-copy-text='some_tag' data-copy-label='tag'").click();
      await settle();

      expect(alert).toHaveBeenCalledWith("Failed to copy tag to clipboard.");
    });

    it("falls back to a generic label", async () => {
      writeText.mockRejectedValue(new Error("denied"));
      const { alert } = await load();
      renderButton("data-copy-text='x'").click();
      await settle();

      expect(alert).toHaveBeenCalledWith("Failed to copy text to clipboard.");
    });

    it("handles clicks on the icon inside the button", async () => {
      await load();
      renderButton("data-copy-text='via_icon'").querySelector("svg")!.dispatchEvent(new MouseEvent("click", { bubbles: true }));
      await settle();

      expect(writeText).toHaveBeenCalledWith("via_icon");
    });

    it("handles buttons inserted after bootstrap", async () => {
      await load();
      await settle();
      renderButton("data-copy-text='late'").click();
      await settle();

      expect(writeText).toHaveBeenCalledWith("late");
    });

    it("ignores copy buttons without data-copy-text", async () => {
      await load();
      renderButton("").click();
      await settle();

      expect(writeText).not.toHaveBeenCalled();
    });

    it("copies once after the module is re-imported", async () => {
      await load();
      vi.resetModules();
      await load();
      renderButton("data-copy-text='once'").click();
      await settle();

      expect(writeText).toHaveBeenCalledTimes(1);
    });
  });

  describe("create()", () => {
    it("builds a titled button with the copy icon", async () => {
      const { CopyButton } = await load();
      const button = CopyButton.create({ label: "code", text: () => "" });

      expect(button.type).toBe("button");
      expect(button.classList.contains("copy-button")).toBe(true);
      expect(button.title).toBe("Copy code to clipboard");
      expect(button.querySelector("svg[name='copy']")).not.toBeNull();
    });

    it("resolves the text at click time", async () => {
      const { CopyButton } = await load();
      let value = "before";
      const button = CopyButton.create({ label: "code", text: () => value });
      document.body.append(button);

      value = "after";
      button.click();
      await settle();

      expect(writeText).toHaveBeenCalledWith("after");
      expect(writeText).toHaveBeenCalledTimes(1);
    });
  });
});
