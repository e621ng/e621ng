import { describe, expect, it } from "vitest";
import { addTagGrouped, removeTagGrouped } from "@/pages/uploads/new/tag_field.js";

// The grouped variants serve the post-show tag editor, whose value keeps the
// newline-per-category grouping. Component-level behaviour is pinned in
// test/components/posts/tag_editor.pushtag.test.ts; this spec covers the edge
// cases the component boundary can't reach.

describe("uploads/tag_field — grouped helpers", () => {
  describe("addTagGrouped", () => {
    it("appends with a trailing space, preserving the value verbatim", () => {
      expect(addTagGrouped("Wolf canine\nforest tree ", "feral")).toBe("Wolf canine\nforest tree feral ");
    });

    it("inserts a separating space when the value does not end with one", () => {
      expect(addTagGrouped("wolf", "feral")).toBe("wolf feral ");
    });

    it("deduplicates case-insensitively across all lines", () => {
      expect(addTagGrouped("other\nWolf ", "wolf")).toBe("other\nWolf ");
    });
  });

  describe("removeTagGrouped", () => {
    it("returns the value unchanged when the tag is absent", () => {
      const value = "Wolf   canine\nforest tree ";
      expect(removeTagGrouped(value, "feral")).toBe(value);
    });

    it("rewrites only the line holding the tag, preserving other lines and casing", () => {
      expect(removeTagGrouped("Wolf   Canine\nForest Tree ", "canine")).toBe("Wolf\nForest Tree ");
    });

    it("removes every occurrence, across lines and within one", () => {
      expect(removeTagGrouped("wolf dog wolf\nwolf tree ", "wolf")).toBe("dog\ntree ");
    });

    it("keeps the trailing-space convention when the last line is rewritten", () => {
      expect(removeTagGrouped("wolf canine\nforest tree ", "tree")).toBe("wolf canine\nforest ");
    });
  });
});
