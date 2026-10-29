import { describe, expect, it, vi } from "vitest";

const blacklist = { reveal: vi.fn() };
vi.mock("@/core/blacklist", () => ({ default: blacklist }));

function page (blacklisted: boolean, video = false) {
  $("body").append(`
    <section id="image-container" class="${blacklisted ? "blacklisted" : ""}" data-id="42" data-file-ext="${video ? "webm" : "png"}">
      ${video ? "<video></video>" : "<img>"}
    </section>
    <section id="note-container"></section>`);
  return $("#image-container");
}

async function load () {
  blacklist.reveal.mockReset();
  void (await import("@/pages/posts/show/BlacklistedImage")).default.instance;
}

describe("BlacklistedImage", () => {
  it("hides the notes and pauses the video when bound on a blacklisted image", async () => {
    const $container = page(true, true);
    const pause = vi.fn();
    ($container.find("video")[0] as HTMLVideoElement).pause = pause;
    await load();

    expect($("#note-container").css("visibility")).toBe("hidden");
    expect(pause).toHaveBeenCalledOnce();
  });

  it("follows the blacklist events", async () => {
    const $container = page(false);
    await load();
    expect($("#note-container").css("visibility")).toBe("visible");

    $container.trigger("blk:hide");
    expect($("#note-container").css("visibility")).toBe("hidden");
    $container.trigger("blk:show");
    expect($("#note-container").css("visibility")).toBe("visible");
  });

  it("reveals the post on click, only while blacklisted", async () => {
    const $container = page(false);
    await load();

    $container.trigger("click");
    expect(blacklist.reveal).not.toHaveBeenCalled();

    $container.addClass("blacklisted").trigger("click");
    expect(blacklist.reveal).toHaveBeenCalledWith(42);
  });

  it("does nothing without an image container", async () => {
    await load();
    expect($("#note-container").length).toBe(0);
  });
});
