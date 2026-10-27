import { describe, expect, it } from "vitest";
import { allUrlsValid, isUrlValid, splitUrls } from "@/pages/posts/show/SourceValidation";

describe("SourceValidation", () => {
  describe("isUrlValid", () => {
    it.each([
      ["https://example.com/a", true],
      ["http://example.com", true],
      ["  https://example.com  ", true],
      ["", true],
      ["   ", true],
      ["-https://dead.example.com", true],
      ["ftp://example.com", false],
      ["javascript:alert(1)", false],
      ["not a url", false],
      ["-ftp://example.com", false],
    ])("%j → %s", (url, expected) => {
      expect(isUrlValid(url)).toBe(expected);
    });

    it("accepts values on the ignore list, compared after trimming", () => {
      expect(isUrlValid("garbage", ["garbage"])).toBe(true);
      expect(isUrlValid("  garbage ", ["garbage"])).toBe(true);
      expect(isUrlValid("garbage", ["other"])).toBe(false);
    });
  });

  describe("allUrlsValid", () => {
    it("requires every url to be valid unless ignored", () => {
      expect(allUrlsValid(["https://a.example", "https://b.example"])).toBe(true);
      expect(allUrlsValid(["https://a.example", "nope"])).toBe(false);
      expect(allUrlsValid(["https://a.example", "nope"], ["nope"])).toBe(true);
      expect(allUrlsValid([])).toBe(true);
    });
  });

  describe("splitUrls", () => {
    it("splits on either line ending and tolerates missing input", () => {
      expect(splitUrls("a\nb")).toEqual(["a", "b"]);
      expect(splitUrls("a\r\nb")).toEqual(["a", "b"]);
      expect(splitUrls(undefined)).toEqual([]);
      expect(splitUrls(null)).toEqual([]);
      expect(splitUrls("")).toEqual([""]); // a blank line, which isUrlValid accepts
    });
  });
});
