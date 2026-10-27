import { describe, expect, it, vi } from "vitest";
import { setSiteData, tick } from "../../helpers";

const hotkeys = { register: vi.fn() };
vi.mock("@/core/hotkeys", () => ({ default: hotkeys }));

const WIDGET = `
<section class="blacklist-ui staged" filters="0" collapsed="true">
  <div class="blacklist-header">Blacklisted <span class="blacklisted-count"></span></div>
  <ul class="blacklist-filters"></ul>
  <span class="blacklist-footer">
    <button type="button" class="blacklist-toggle-all">Disable All Filters</button>
  </span>
</section>`;

function thumb (tags: string, id: number): JQuery<HTMLElement> {
  const $article = $("<article>").addClass("thumbnail blacklistable")
    .attr({ "data-id": id, "data-tags": tags, "data-flags": "", "data-rating": "s" });
  $("body").append($article);
  return $article;
}

async function load (blacklist: string[], post?: number) {
  setSiteData("site-user", { id: 5, blacklist });
  $("body").append(WIDGET);
  if (post) $("section.blacklist-ui").attr("post", post);
  const Blacklist = (await import("@/core/blacklist")).default;
  const BlacklistWidget = (await import("@/core/blacklist/BlacklistWidget")).default;
  BlacklistWidget.initializeAll();
  await tick();
  const $widget = $("section.blacklist-ui");
  const entries = () => $widget.find("li").map((_, el) => {
    const $a = $(el).find("a");
    return $a.contents().first().text() + ":" + $(el).attr("enabled");
  }).get();
  return { Blacklist, $widget, entries };
}

describe("BlacklistWidget", () => {
  it("lists only the filters that match something on the page", async () => {
    thumb("fox", 1);
    thumb("fox wolf", 2);
    const { $widget, entries } = await load(["fox", "wolf", "unused"]);

    expect($widget.hasClass("staged")).toBe(false);
    expect(entries()).toEqual(["fox:true", "wolf:true"]);
    expect($widget.find("li a span").map((_, el) => $(el).text()).get()).toEqual(["2", "1"]);
    expect($widget.attr("filters")).toBe("2");
    expect($widget.find(".blacklisted-count").text()).toBe("(2)");
    expect(hotkeys.register).toHaveBeenCalledWith("blacklist", expect.any(Function));
  });

  it("only lists filters matching the current post on posts#show", async () => {
    thumb("fox", 1);
    thumb("wolf", 2);
    const { entries } = await load(["fox", "wolf"], 2);
    expect(entries()).toEqual(["wolf:true"]);
  });

  it("toggles a filter and rebuilds after the commit", async () => {
    const $thumb = thumb("fox", 1);
    const { $widget, entries, Blacklist } = await load(["fox"]);

    $widget.find("li").first().trigger("click");
    await tick();
    expect(Blacklist.filters["fox"].enabled).toBe(false);
    expect($thumb.hasClass("blacklisted")).toBe(false);
    expect(entries()).toEqual(["fox:false"]);
    expect($widget.find(".blacklisted-count").text()).toBe("(0)");
    expect($widget.find("button").text()).toBe("Enable All Filters");
    expect($widget.find("button").attr("is-enabling")).toBe("true");
  });

  it("toggles everything through the button and the hotkey", async () => {
    const $thumb = thumb("fox", 1);
    const { $widget, Blacklist } = await load(["fox", "wolf"]);

    $widget.find("button").trigger("click");
    await tick();
    expect($thumb.hasClass("blacklisted")).toBe(false);
    expect(Blacklist.filters["wolf"].enabled).toBe(false);
    expect(JSON.parse(localStorage.getItem("e6.blk.filters")!).sort()).toEqual(["fox", "wolf"]);
    expect($widget.find("button").text()).toBe("Enable All Filters");

    hotkeys.register.mock.calls.at(-1)![1]();
    await tick();
    expect($thumb.hasClass("blacklisted")).toBe(true);
    expect($widget.find("button").text()).toBe("Disable All Filters");
    expect(localStorage.getItem("e6.blk.filters")).toBeNull();
  });

  it("follows thumbnails as they come and go", async () => {
    const { $widget } = await load(["fox"]);
    expect($widget.find("li").length).toBe(0);

    const $thumb = thumb("fox", 1);
    await tick();
    expect($widget.find("li").length).toBe(1);
    expect($widget.find(".blacklisted-count").text()).toBe("(1)");

    $thumb.remove();
    await tick();
    expect($widget.find("li").length).toBe(0);
    expect($widget.find(".blacklisted-count").text()).toBe("(0)");
  });
});
