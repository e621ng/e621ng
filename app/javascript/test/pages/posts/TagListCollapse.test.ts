import { describe, expect, it } from "vitest";

function render () {
  $("body").append(`
    <h5 class="tag-list-header artist-tag-list-header" data-category="artist">Artist</h5>
    <ul class="tag-list artist-tag-list"><li>a</li></ul>
    <h5 class="tag-list-header species-tag-list-header" data-category="species">Species</h5>
    <ul class="tag-list species-tag-list"><li>s</li></ul>
    <h5 class="tag-list-header" data-category="lonely">Lonely</h5>
  `);
}

async function load () {
  const TagListCollapse = (await import("@/pages/posts/TagListCollapse")).default;
  TagListCollapse.initialize();
}

const hidden = (selector: string) => document.querySelector<HTMLElement>(selector).style.display === "none";

describe("TagListCollapse", () => {
  it("collapses and restores a category from its header", async () => {
    render();
    await load();
    const header = $(".artist-tag-list-header");

    const event = $.Event("click");
    header.trigger(event);
    expect(event.isDefaultPrevented()).toBe(true);
    expect(hidden(".artist-tag-list")).toBe(true);
    expect(header.hasClass("hidden-category")).toBe(true);

    header.trigger("click");
    expect(hidden(".artist-tag-list")).toBe(false);
    expect(header.hasClass("hidden-category")).toBe(false);
  });

  it("keeps categories independent", async () => {
    render();
    await load();

    $(".species-tag-list-header").trigger("click");

    expect(hidden(".species-tag-list")).toBe(true);
    expect(hidden(".artist-tag-list")).toBe(false);
    expect($(".artist-tag-list-header").hasClass("hidden-category")).toBe(false);
  });

  it("tolerates a header without a list", async () => {
    render();
    await load();

    $("[data-category=lonely]").trigger("click");

    expect($("[data-category=lonely]").hasClass("hidden-category")).toBe(true);
  });
});
