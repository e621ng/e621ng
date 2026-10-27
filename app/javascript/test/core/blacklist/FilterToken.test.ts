import { describe, expect, it } from "vitest";

async function load () {
  return (await import("@/core/blacklist/FilterToken")).default;
}

describe("FilterToken", () => {
  it("treats a bare word as a tag", async () => {
    const FilterToken = await load();
    const token = new FilterToken("fox");
    expect(token).toMatchObject({ type: "tag", value: "fox", optional: false, inverted: false });
  });

  it("reads the optional and inverted prefixes", async () => {
    const FilterToken = await load();
    expect(new FilterToken("~fox")).toMatchObject({ optional: true, inverted: false, value: "fox" });
    expect(new FilterToken("-fox")).toMatchObject({ optional: false, inverted: true, value: "fox" });
    expect(new FilterToken("~-fox")).toMatchObject({ optional: true, inverted: true, value: "fox" });
  });

  it("parses user ids up front", async () => {
    const FilterToken = await load();
    expect(new FilterToken("user:!12")).toMatchObject({ type: "userid", value: 12, comparison: "=" });
    expect(new FilterToken("-uploader:!12")).toMatchObject({ type: "userid", value: 12, inverted: true });
    expect(new FilterToken("userid:>12")).toMatchObject({ type: "userid", value: 12, comparison: ">" });
    expect(new FilterToken("user:bob")).toMatchObject({ type: "user", value: "bob" });
    expect(new FilterToken("pool:7")).toMatchObject({ type: "pool", value: 7 });
  });

  it("turns wildcards into a regular expression", async () => {
    const FilterToken = await load();
    const token = new FilterToken("fox_*");
    expect(token.type).toBe("wildcard");
    expect(token.value.test("fox_tail")).toBe(true);
    expect(token.value.test("red_fox")).toBe(false);
  });

  it("fudges exact filesizes into a range", async () => {
    const FilterToken = await load();
    const token = new FilterToken("filesize:1mb");
    expect(token.comparison).toBe("..");
    expect(token.value).toEqual([Math.trunc(1048576 * 0.95), Math.trunc(1048576 * 1.05)]);
  });
});
