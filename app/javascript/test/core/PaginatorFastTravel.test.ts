import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const assign = vi.fn();
const originalLocation = window.location;

function stubLocation (href: string) {
  const fake = new URL(href) as unknown as Location;
  fake.assign = assign;
  Object.defineProperty(window, "location", { configurable: true, writable: true, value: fake });
}

function render (total = 20) {
  document.body.innerHTML = `
    <nav class="pagination numbered" data-total="${total}" data-current="5">
      <a class="page first" href="/posts?page=1">1</a>
      <button type="button" class="page spacer link" title="Jump to page"><svg></svg></button>
    </nav>`;
  return document.querySelector<HTMLButtonElement>("button.spacer");
}

async function load () {
  vi.resetModules();
  const PaginatorFastTravel = (await import("@/core/PaginatorFastTravel")).default;
  PaginatorFastTravel.bootstrap();
  return PaginatorFastTravel;
}

function stubPrompt (...answers: (string | null)[]) {
  const prompt = vi.fn<(message?: string, initial?: string) => string | null>();
  for (const answer of answers) prompt.mockReturnValueOnce(answer);
  vi.stubGlobal("prompt", prompt);
  return prompt;
}

describe("PaginatorFastTravel", () => {
  beforeEach(() => {
    assign.mockReset();
    stubLocation("http://localhost/posts?tags=fox&page=5&limit=50");
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    Object.defineProperty(window, "location", { configurable: true, writable: true, value: originalLocation });
    document.body.innerHTML = "";
  });

  describe("parse", () => {
    it("accepts pages within range", async () => {
      const { parse } = await load();
      expect(parse("1", 20)).toEqual({ page: 1 });
      expect(parse("20", 20)).toEqual({ page: 20 });
      expect(parse(" 7 ", 20)).toEqual({ page: 7 });
    });

    it("returns null for cancelled or empty input", async () => {
      const { parse } = await load();
      expect(parse(null, 20)).toBeNull();
      expect(parse("", 20)).toBeNull();
      expect(parse("   ", 20)).toBeNull();
    });

    it.each(["abc", "0", "-1", "1.5", "1e3", "21", "0x10", "5abc"])("rejects %j", async (input) => {
      const { parse } = await load();
      expect(parse(input, 20)).toEqual({ error: "Enter a page number between 1 and 20." });
    });
  });

  describe("urlFor", () => {
    it("swaps only the page parameter", async () => {
      const { urlFor } = await load();
      const url = new URL(urlFor(12));
      expect(url.pathname).toBe("/posts");
      expect(url.searchParams.get("page")).toBe("12");
      expect(url.searchParams.get("tags")).toBe("fox");
      expect(url.searchParams.get("limit")).toBe("50");
    });

    it("adds the page parameter when missing", async () => {
      stubLocation("http://localhost/posts?tags=fox");
      const { urlFor } = await load();
      expect(new URL(urlFor(3)).searchParams.get("page")).toBe("3");
    });
  });

  describe("clicking the ellipsis", () => {
    it("navigates to the entered page, keeping history", async () => {
      const button = render();
      stubPrompt("12");
      await load();
      button.click();

      expect(assign).toHaveBeenCalledTimes(1);
      expect(new URL(assign.mock.calls[0][0]).searchParams.get("page")).toBe("12");
    });

    it("does nothing when cancelled", async () => {
      const button = render();
      stubPrompt(null);
      await load();
      button.click();

      expect(assign).not.toHaveBeenCalled();
    });

    it("re-prompts with the error and previous input on invalid input", async () => {
      const button = render();
      const prompt = stubPrompt("abc", "9");
      await load();
      button.click();

      expect(prompt).toHaveBeenNthCalledWith(2, "Enter a page number between 1 and 20.", "abc");
      expect(new URL(assign.mock.calls[0][0]).searchParams.get("page")).toBe("9");
    });

    it("gives up when the re-prompt is cancelled", async () => {
      const button = render();
      const prompt = stubPrompt("99", null);
      await load();
      button.click();

      expect(prompt).toHaveBeenCalledTimes(2);
      expect(assign).not.toHaveBeenCalled();
    });

    it("uses the nav's page total", async () => {
      const button = render(750);
      stubPrompt("750");
      await load();
      button.click();

      expect(new URL(assign.mock.calls[0][0]).searchParams.get("page")).toBe("750");
    });

    it("does not stack listeners across re-imports", async () => {
      const button = render();
      const prompt = stubPrompt("3");
      await load();
      await load();
      button.click();

      expect(prompt).toHaveBeenCalledTimes(1);
      expect(assign).toHaveBeenCalledTimes(1);
    });
  });
});
