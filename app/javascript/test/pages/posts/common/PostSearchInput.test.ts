import { describe, expect, it, vi } from "vitest";

function render (count = 1) {
  for (let i = 0; i < count; i++) {
    document.body.insertAdjacentHTML("beforeend", `
      <section class="post-search">
        <form class="post-search-form">
          <input type="hidden" name="random" value="1">
          <textarea name="tags" rows="1"></textarea>
          <button type="submit">Search</button>
        </form>
      </section>
    `);
  }
}

async function load () {
  const PostSearchInput = (await import("@/pages/posts/common/PostSearchInput")).default;
  void PostSearchInput.instance;
}

function textareas () {
  return [...document.querySelectorAll<HTMLTextAreaElement>("textarea[name=tags]")];
}

/** jsdom does no layout, so scrollHeight is always 0 unless stubbed */
function stubScrollHeight (textarea: HTMLTextAreaElement, initial: number) {
  let value = initial;
  Object.defineProperty(textarea, "scrollHeight", { configurable: true, get: () => value });
  return (next: number) => { value = next; };
}

function pressEnter (textarea: HTMLTextAreaElement, init: KeyboardEventInit = {}) {
  const event = new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true, ...init });
  textarea.dispatchEvent(event);
  return event;
}

/** Counts submissions; cancels them so jsdom does not attempt navigation */
function trackSubmits (form: HTMLFormElement) {
  const submit = vi.fn((event: Event) => event.preventDefault());
  form.addEventListener("submit", submit);
  return submit;
}

describe("PostSearchInput", () => {
  describe("auto height", () => {
    it("sizes the textarea to its content on load", async () => {
      render();
      stubScrollHeight(textareas()[0], 42);
      await load();

      expect(textareas()[0].style.height).toBe("42px");
    });

    it("resizes on input", async () => {
      render();
      const setHeight = stubScrollHeight(textareas()[0], 20);
      await load();

      setHeight(60);
      textareas()[0].dispatchEvent(new Event("input"));

      expect(textareas()[0].style.height).toBe("60px");
    });

    it("resizes when the window does", async () => {
      render();
      const setHeight = stubScrollHeight(textareas()[0], 20);
      await load();

      setHeight(35);
      window.dispatchEvent(new Event("resize"));

      expect(textareas()[0].style.height).toBe("35px");
    });
  });

  describe("Enter to submit", () => {
    it("submits the form through its submit handlers", async () => {
      render();
      await load();
      const submit = trackSubmits(textareas()[0].form);

      const event = pressEnter(textareas()[0]);

      expect(event.defaultPrevented).toBe(true);
      expect(submit).toHaveBeenCalledOnce();
    });

    it.each([
      ["Shift+Enter", { shiftKey: true }],
      ["Enter during IME composition", { isComposing: true }],
    ])("ignores %s", async (_label, init) => {
      render();
      await load();
      const submit = trackSubmits(textareas()[0].form);

      const event = pressEnter(textareas()[0], init);

      expect(event.defaultPrevented).toBe(false);
      expect(submit).not.toHaveBeenCalled();
    });

    it("ignores other keys", async () => {
      render();
      await load();
      const submit = trackSubmits(textareas()[0].form);

      textareas()[0].dispatchEvent(new KeyboardEvent("keydown", { key: "a", bubbles: true, cancelable: true }));

      expect(submit).not.toHaveBeenCalled();
    });

    it("leaves an Enter claimed by autocomplete alone, even when autocomplete binds later", async () => {
      render();
      await load();
      const textarea = textareas()[0];
      const submit = trackSubmits(textarea.form);
      textarea.addEventListener("keydown", (event) => event.preventDefault());

      pressEnter(textarea);

      expect(submit).not.toHaveBeenCalled();
    });

    it("leaves an Enter stopped by autocomplete alone", async () => {
      render();
      await load();
      const textarea = textareas()[0];
      const submit = trackSubmits(textarea.form);
      textarea.addEventListener("keydown", (event) => event.stopPropagation());

      pressEnter(textarea);

      expect(submit).not.toHaveBeenCalled();
    });

    it("ignores Enter in other fields of the form", async () => {
      render();
      await load();
      const form = textareas()[0].form;
      const submit = trackSubmits(form);
      const other = document.createElement("textarea");
      form.append(other);

      pressEnter(other);

      expect(submit).not.toHaveBeenCalled();
    });
  });

  it("binds each search section independently", async () => {
    render(2);
    const [first, second] = textareas();
    stubScrollHeight(first, 10);
    stubScrollHeight(second, 30);
    await load();
    const firstSubmit = trackSubmits(first.form);
    const secondSubmit = trackSubmits(second.form);

    pressEnter(second);

    expect(first.style.height).toBe("10px");
    expect(second.style.height).toBe("30px");
    expect(firstSubmit).not.toHaveBeenCalled();
    expect(secondSubmit).toHaveBeenCalledOnce();
  });

  it("tolerates a search section without a textarea", async () => {
    document.body.innerHTML = "<section class=\"post-search\"><form></form></section>";
    await expect(load()).resolves.toBeUndefined();
  });
});
