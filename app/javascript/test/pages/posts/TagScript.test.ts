import { describe, expect, it } from "vitest";
import TagScript, { TagScriptError } from "@/pages/posts/TagScript";

const run = (script: string, tags: string[] = []) => TagScript.evaluate(TagScript.parse(script), new Set(tags));

describe("TagScript", () => {
  describe("parse", () => {
    it("returns plain and negated tags as unconditional commands", () => {
      expect(TagScript.parse("wolf  -canine")).toEqual([{ tags: ["wolf"] }, { tags: ["-canine"] }]);
    });

    it("returns nothing for empty or whitespace-only scripts", () => {
      expect(TagScript.parse("")).toEqual([]);
      expect(TagScript.parse("  \t ")).toEqual([]);
    });

    it("ignores [reset]", () => {
      expect(TagScript.parse("a [reset] [RESET] b")).toEqual([{ tags: ["a"] }, { tags: ["b"] }]);
    });

    it("parses conditionals with multi-tag predicates and consequents", () => {
      const expected = { tags: ["male", "-female"], when: { require: ["wolf", "solo"], exclude: ["canine"] } };
      expect(TagScript.parse("[if Wolf -Canine solo,  male -female ]")).toEqual([expected]);
    });

    it("ignores a bare dash in the predicate", () => {
      expect(TagScript.parse("[if a -, b]")[0].when).toEqual({ require: ["a"], exclude: [] });
    });

    it.each([
      ["[if a b]", "missing comma"],
      ["[if , b]", "empty predicate"],
      ["[if   , b]", "blank predicate"],
      ["[if a, ]", "empty consequent"],
      ["[if a, b, c]", "extra comma"],
      ["[iffy, b]", "no space after if"],
      ["[fi a, b]", "unknown command"],
      ["[]", "empty brackets"],
      ["x [if a, b", "unterminated bracket"],
    ])("rejects %s (%s)", (script) => {
      expect(() => TagScript.parse(script)).toThrow(TagScriptError);
    });

    it("names the offending command in the error", () => {
      expect(() => TagScript.parse("ok [fi a, b]")).toThrow("Invalid tag script command: [fi a, b]");
    });
  });

  describe("evaluate", () => {
    it("emits unconditional changes in order", () => {
      expect(run("b -a c")).toEqual(["b", "-a", "c"]);
    });

    it("emits a consequent only when all required tags are present", () => {
      expect(run("[if a b, x y]", ["a", "b"])).toEqual(["x", "y"]);
      expect(run("[if a b, x y]", ["a"])).toEqual([]);
    });

    it("skips a consequent when an excluded tag is present", () => {
      expect(run("[if a -b, x]", ["a"])).toEqual(["x"]);
      expect(run("[if a -b, x]", ["a", "b"])).toEqual([]);
    });

    it("matches predicates case-insensitively", () => {
      expect(run("[if Wolf, x]", ["wolf"])).toEqual(["x"]);
    });

    it("mixes conditionals with plain tags", () => {
      expect(run("p [if a, x] [if b, y] -q", ["a"])).toEqual(["p", "x", "-q"]);
    });
  });

  describe("hasConditionals", () => {
    it("detects [if] commands", () => {
      expect(TagScript.hasConditionals(TagScript.parse("a -b [reset]"))).toBe(false);
      expect(TagScript.hasConditionals(TagScript.parse("a [if b, c]"))).toBe(true);
    });
  });
});
