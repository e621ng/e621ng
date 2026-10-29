import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const DECLINE = "You must accept the TOU and confirm that you are at least 18 years old to use this site.";

function render ({ checked = false } = {}) {
  const attr = checked ? " checked" : "";
  document.body.innerHTML = `
    <div id="toast-container"></div>
    <div class="tos-modal-container">
      <form id="tos-form" data-tos-version="7" action="/terms_of_use/accept" method="post">
        <input type="checkbox" id="tos-age-checkbox" name="age"${attr} />
        <input type="checkbox" id="tos-terms-checkbox" name="terms"${attr} />
        <button type="submit" id="tos-warning-accept" class="st-button submit disabled" aria-disabled="true">Accept</button>
        <button type="submit" id="tos-warning-decline" class="st-button">Decline</button>
      </form>
    </div>`;
}

const el = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;
const age = () => el<HTMLInputElement>("tos-age-checkbox");
const terms = () => el<HTMLInputElement>("tos-terms-checkbox");
const accept = () => el<HTMLButtonElement>("tos-warning-accept");
const decline = () => el<HTMLButtonElement>("tos-warning-decline");

function toggle (box: HTMLInputElement) {
  box.click(); // flips `checked` and fires change
}

function submit (): SubmitEvent {
  const event = new SubmitEvent("submit", { bubbles: true, cancelable: true, submitter: accept() });
  el("tos-form").dispatchEvent(event);
  return event;
}

// Importing the module bootstraps it against the current document.
// Toast is re-imported after the reset so spies land on the instance the module uses.
async function load () {
  vi.resetModules();
  const ToastManager = (await import("@/utility/Toast")).default;
  const create = vi.spyOn(ToastManager, "create");
  await import("@/core/TOSWarning");
  return { create };
}

describe("TOSWarning", () => {
  beforeEach(() => {
    document.cookie = "tos_accepted=; path=/; max-age=0";
  });

  afterEach(() => {
    vi.restoreAllMocks();
    document.body.innerHTML = "";
    document.body.className = "";
    document.cookie = "tos_accepted=; path=/; max-age=0";
  });

  it("does nothing when the modal is not rendered", async () => {
    await expect(load()).resolves.toBeDefined();
    expect(document.body.classList.contains("scroll-lock")).toBe(false);
  });

  describe("on load", () => {
    it("locks page scrolling", async () => {
      render();
      await load();
      expect(document.body.classList.contains("scroll-lock")).toBe(true);
    });

    it("clears checkboxes restored by the browser", async () => {
      render({ checked: true });
      await load();
      expect(age().checked).toBe(false);
      expect(terms().checked).toBe(false);
      expect(accept().classList.contains("disabled")).toBe(true);
    });

    it("focuses the age checkbox", async () => {
      render();
      await load();
      expect(document.activeElement).toBe(age());
    });
  });

  describe("accept button state", () => {
    beforeEach(async () => {
      render();
      await load();
    });

    it("stays disabled with only one box checked", () => {
      toggle(age());
      expect(accept().classList.contains("disabled")).toBe(true);
      expect(accept().getAttribute("aria-disabled")).toBe("true");
    });

    it("enables once both boxes are checked", () => {
      toggle(age());
      toggle(terms());
      expect(accept().classList.contains("disabled")).toBe(false);
      expect(accept().getAttribute("aria-disabled")).toBe("false");
    });

    it("disables again when a box is unchecked", () => {
      toggle(age());
      toggle(terms());
      toggle(terms());
      expect(accept().classList.contains("disabled")).toBe(true);
      expect(accept().getAttribute("aria-disabled")).toBe("true");
    });

    it("never sets the real disabled attribute", () => {
      toggle(age());
      expect(accept().disabled).toBe(false);
    });
  });

  describe("focus handoff", () => {
    it("moves focus to the terms checkbox after the first age change only", async () => {
      render();
      await load();

      toggle(age());
      expect(document.activeElement).toBe(terms());

      age().focus();
      toggle(age());
      expect(document.activeElement).toBe(age());
    });
  });

  describe("submitting", () => {
    beforeEach(async () => {
      render();
      await load();
    });

    it("is blocked while a box is unchecked", () => {
      toggle(age());
      const event = submit();

      expect(event.defaultPrevented).toBe(true);
      expect(document.cookie).not.toContain("tos_accepted");
      expect(document.querySelector(".tos-modal-container")).not.toBeNull();
      expect(document.body.classList.contains("scroll-lock")).toBe(true);
    });

    it("accepts client-side when both boxes are checked", () => {
      toggle(age());
      toggle(terms());
      const event = submit();

      expect(event.defaultPrevented).toBe(true);
      expect(document.cookie).toContain("tos_accepted=7");
      expect(document.querySelector(".tos-modal-container")).toBeNull();
      expect(document.body.classList.contains("scroll-lock")).toBe(false);
    });

    it("writes a long-lived, non-Secure cookie over http", () => {
      const descriptor = Object.getOwnPropertyDescriptor(Document.prototype, "cookie")!;
      const setter = vi.spyOn(descriptor, "set");
      Object.defineProperty(document, "cookie", { ...descriptor, configurable: true });

      try {
        toggle(age());
        toggle(terms());
        submit();

        expect(setter).toHaveBeenCalledWith("tos_accepted=7; path=/; max-age=630720000; SameSite=Lax");
      } finally {
        delete (document as { cookie?: string }).cookie;
      }
    });
  });

  describe("declining", () => {
    it("shows an alert toast without submitting", async () => {
      render();
      const { create } = await load();
      const onSubmit = vi.fn();
      el("tos-form").addEventListener("submit", onSubmit);

      decline().click();

      expect(create).toHaveBeenCalledWith(DECLINE, { type: "alert" });
      expect(onSubmit).not.toHaveBeenCalled();
      expect(document.cookie).not.toContain("tos_accepted");
      expect(document.querySelector(".tos-modal-container")).not.toBeNull();
    });

    it("replaces the previous toast on repeated clicks", async () => {
      render();
      const { create } = await load();

      decline().click();
      const first = create.mock.results[0].value;
      const dismiss = vi.spyOn(first, "dismiss");

      decline().click();

      expect(dismiss).toHaveBeenCalledWith();
      expect(create).toHaveBeenCalledTimes(2);
      expect(create.mock.results[1].value).not.toBe(first);
    });

    it("dismisses the toast immediately once accepted", async () => {
      render();
      const { create } = await load();

      decline().click();
      const dismiss = vi.spyOn(create.mock.results[0].value, "dismiss");

      toggle(age());
      toggle(terms());
      submit();

      expect(dismiss).toHaveBeenCalledWith(true);
    });
  });
});
