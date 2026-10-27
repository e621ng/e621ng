import { describe, expect, it, vi } from "vitest";
import { setSiteData, tick } from "../../helpers";

function comment (creator: string, creatorID: number): JQuery<HTMLElement> {
  const $article = $("<article>").addClass("comment")
    .attr({ "data-creator": creator, "data-creator-id": creatorID });
  $("body").append($article);
  return $article;
}

async function load (blacklist: string[], blacklistUsers = true) {
  setSiteData("site-user", { id: 5, blacklist, settings: { blacklist_users: blacklistUsers } });
  const Blacklist = (await import("@/core/blacklist")).default;
  const CommentBlacklist = (await import("@/core/blacklist/CommentBlacklist")).default;
  CommentBlacklist.initializeAll();
  await tick();
  return { Blacklist, CommentBlacklist };
}

describe("CommentBlacklist", () => {
  it("marks comments by name and by id", async () => {
    const $bob = comment("bob", 12);
    const $alice = comment("alice", 13);
    const $carol = comment("carol", 14);
    const $dave = comment("dave", 15);
    await load(["user:bob", "user:!13", "userid:14", "username:eve"]);

    expect($bob.hasClass("blacklisted-user")).toBe(true);
    expect($alice.hasClass("blacklisted-user")).toBe(true);
    expect($carol.hasClass("blacklisted-user")).toBe(true);
    expect($dave.hasClass("blacklisted-user")).toBe(false);
  });

  it("follows blacklist edits", async () => {
    const $bob = comment("bob", 12);
    const $alice = comment("alice", 13);
    await load(["user:bob"]);
    expect($bob.hasClass("blacklisted-user")).toBe(true);

    vi.stubGlobal("fetch", vi.fn(() => Promise.resolve({ ok: true, json: () => Promise.resolve({}) })));
    const CurrentUser = (await import("@/models/CurrentUser")).default;
    CurrentUser.blacklist = ["user:alice"];
    await tick();
    expect($bob.hasClass("blacklisted-user")).toBe(false);
    expect($alice.hasClass("blacklisted-user")).toBe(true);
  });

  it("does nothing when the setting is off", async () => {
    const $bob = comment("bob", 12);
    await load(["user:bob"], false);
    expect($bob.hasClass("blacklisted-user")).toBe(false);
  });

  it("escapes the value", async () => {
    const $odd = comment("a\"b", 12);
    await load(["user:a\"b"]);
    expect($odd.hasClass("blacklisted-user")).toBe(true);
  });
});
