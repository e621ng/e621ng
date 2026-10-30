import { describe, expect, it } from "vitest";
import { setSiteData } from "../../../helpers";

function render () {
  $("body").append(`
    <article id="post_42" class="thumbnail"></article>
    <article id="post_7" class="thumbnail"></article>
    <div id="has-parent-relationship-preview" style="display: none;"></div>
    <a id="has-parent-relationship-preview-link" href="#">show »</a>
    <div id="has-children-relationship-preview" style="display: none;"></div>
    <a id="has-children-relationship-preview-link" href="#">show »</a>
  `);
}

async function load ({ shown = false } = {}) {
  setSiteData("post-data", { id: 42 });
  setSiteData("site-user", { id: 5 }); // CurrentPost pulls in CurrentUser, which logs without it
  const LStorage = (await import("@/utility/storage/Local")).default;
  LStorage.Posts.ShowPostChildren = shown;
  const RelationshipPreview = (await import("@/pages/posts/show/RelationshipPreview")).default;
  return { RelationshipPreview: RelationshipPreview.instance, LStorage };
}

const displays = () => [
  document.getElementById("has-parent-relationship-preview").style.display,
  document.getElementById("has-children-relationship-preview").style.display,
];
const texts = () => [$("#has-parent-relationship-preview-link").text(), $("#has-children-relationship-preview-link").text()];

describe("RelationshipPreview", () => {
  it("starts collapsed by default", async () => {
    render();
    await load();

    expect(displays()).toEqual(["none", "none"]);
    expect(texts()).toEqual(["show »", "show »"]);
  });

  it("applies the persisted expanded state on load", async () => {
    render();
    await load({ shown: true });

    expect(displays()).toEqual(["", ""]);
    expect(texts()).toEqual(["« hide", "« hide"]);
  });

  it("toggles both previews together and persists the choice", async () => {
    render();
    const { LStorage } = await load();

    const event = $.Event("click");
    $("#has-children-relationship-preview-link").trigger(event);
    expect(event.isDefaultPrevented()).toBe(true);
    expect(displays()).toEqual(["", ""]);
    expect(texts()).toEqual(["« hide", "« hide"]);
    expect(LStorage.Posts.ShowPostChildren).toBe(true);

    $("#has-parent-relationship-preview-link").trigger("click");
    expect(displays()).toEqual(["none", "none"]);
    expect(texts()).toEqual(["show »", "show »"]);
    expect(LStorage.Posts.ShowPostChildren).toBe(false);
  });

  it("highlights the current post among the thumbnails", async () => {
    render();
    await load();

    expect($("#post_42").hasClass("current-post")).toBe(true);
    expect($("#post_7").hasClass("current-post")).toBe(false);
  });

  it("tolerates a post without relationships", async () => {
    $("body").append('<article id="post_42"></article>');
    await expect(load()).resolves.toBeDefined();
  });
});
