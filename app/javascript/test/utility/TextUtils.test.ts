import { afterEach, describe, expect, it } from "vitest";
import TextUtils from "@/utility/TextUtils";

function makeTextarea (value = ""): HTMLTextAreaElement {
  const textarea = document.createElement("textarea");
  textarea.value = value;
  document.body.appendChild(textarea);
  return textarea;
}

afterEach(() => {
  document.body.innerHTML = "";
});

describe("TextUtils.focusEnd", () => {
  it("focuses the element and places the cursor at the end", () => {
    const textarea = makeTextarea("hello world");
    textarea.setSelectionRange(0, 0);

    TextUtils.focusEnd(textarea);

    expect(document.activeElement).toBe(textarea);
    expect(textarea.selectionStart).toBe(11);
    expect(textarea.selectionEnd).toBe(11);
  });

  it("works on text inputs", () => {
    const input = document.createElement("input");
    input.type = "text";
    input.value = "abc";
    document.body.appendChild(input);

    TextUtils.focusEnd(input);

    expect(document.activeElement).toBe(input);
    expect(input.selectionStart).toBe(3);
  });
});

describe("TextUtils.processQuote", () => {
  const quote = "[quote]\"bob\":/users/7 said:\nhi\n[/quote]\n\n";

  it("fills an empty textarea with the quote", () => {
    const textarea = makeTextarea();
    TextUtils.processQuote($(textarea) as JQuery<HTMLInputElement>, "hi", "bob", 7);
    expect(textarea.value).toBe(quote);
  });

  it("appends to existing text with a blank-line separator", () => {
    const textarea = makeTextarea("draft");
    TextUtils.processQuote($(textarea) as JQuery<HTMLInputElement>, "hi", "bob", 7);
    expect(textarea.value).toBe("draft\n\n" + quote);
  });

  it("does not double the separator when the text already ends with one", () => {
    const textarea = makeTextarea("draft\n\n");
    TextUtils.processQuote($(textarea) as JQuery<HTMLInputElement>, "hi", "bob", 7);
    expect(textarea.value).toBe("draft\n\n" + quote);
  });

  it("strips nested quotes from the quoted message", () => {
    const textarea = makeTextarea();
    TextUtils.processQuote($(textarea) as JQuery<HTMLInputElement>, "[quote]old[/quote]\nhi", "bob", 7);
    expect(textarea.value).toBe(quote);
  });

  it("leaves the textarea focused with the cursor at the end", () => {
    const textarea = makeTextarea("draft");
    TextUtils.processQuote($(textarea) as JQuery<HTMLInputElement>, "hi", "bob", 7);

    expect(document.activeElement).toBe(textarea);
    expect(textarea.selectionStart).toBe(textarea.value.length);
    expect(textarea.selectionEnd).toBe(textarea.value.length);
  });
});
