import { describe, expect, it } from "vitest";
import { setSiteData } from "../../helpers";

const POST_ID = 42;

function thumb (tags: string): JQuery<HTMLElement> {
  const $article = $("<article>").addClass("thumbnail blacklistable")
    .attr({ "data-id": POST_ID, "data-tags": tags, "data-flags": "", "data-rating": "s" });
  $("body").append($article);
  return $article;
}

async function load () {
  setSiteData("site-user", { id: 5, blacklist: ["hidden_tag"] });
  const Blacklist = (await import("@/core/blacklist")).default;
  // Register what is on the page now, rather than waiting for the DOM-ready hook
  Blacklist.addPosts($(".blacklistable"));
  Blacklist.recalculateMatchedPosts();
  Blacklist.updatePostVisibility();
  return Blacklist;
}

describe("Blacklist.refreshPosts", () => {
  it("unhides a post whose attributes no longer match", async () => {
    const $thumb = thumb("hidden_tag fox");
    const Blacklist = await load();
    expect($thumb.hasClass("blacklisted")).toBe(true);
    expect(Blacklist.hiddenPosts.has(POST_ID)).toBe(true);

    $thumb.attr("data-tags", "fox");
    Blacklist.refreshPosts($thumb);

    expect($thumb.hasClass("blacklisted")).toBe(false);
    expect($thumb.hasClass("filter-matches")).toBe(false);
    expect(Blacklist.hiddenPosts.has(POST_ID)).toBe(false);
    expect(Blacklist.matchedPosts.has(POST_ID)).toBe(false);
  });

  it("hides a post whose attributes now match", async () => {
    const $thumb = thumb("fox");
    const Blacklist = await load();
    expect($thumb.hasClass("blacklisted")).toBe(false);

    $thumb.attr("data-tags", "fox hidden_tag");
    Blacklist.refreshPosts($thumb);

    expect($thumb.hasClass("blacklisted")).toBe(true);
    expect($thumb.hasClass("filter-matches")).toBe(true);
    expect(Blacklist.hiddenPosts.has(POST_ID)).toBe(true);
  });

  it("ignores elements it cannot parse", async () => {
    const Blacklist = await load();
    expect(() => Blacklist.refreshPosts($("<article>"))).not.toThrow();
    expect(Blacklist.hiddenPosts.size).toBe(0);
  });
});
