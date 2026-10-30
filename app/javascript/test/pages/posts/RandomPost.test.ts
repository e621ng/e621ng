import { beforeEach, describe, expect, it, vi } from "vitest";

const hotkeys = new Map<string, () => void>();
vi.mock("@/core/hotkeys", () => ({
  default: { register: (name: string, listener: () => void) => { hotkeys.set(name, listener); } },
}));

async function load () {
  const RandomPost = (await import("@/pages/posts/RandomPost")).default;
  const navigate = vi.spyOn(RandomPost as any, "navigate").mockImplementation(() => {});
  return { RandomPost, navigate };
}

describe("RandomPost", () => {
  beforeEach(() => { hotkeys.clear(); });

  it("targets any random post when there is no search", async () => {
    const { RandomPost } = await load();
    expect(RandomPost.href()).toBe("/posts/random");

    $("body").append('<textarea id="tags">   </textarea>');
    expect(RandomPost.href()).toBe("/posts/random");
  });

  it("narrows to the current search, one encoded tag at a time", async () => {
    $("body").append('<textarea id="tags">rating:s  fox</textarea>');
    const { RandomPost } = await load();

    expect(RandomPost.href()).toBe("/posts/random?tags=rating%3As+fox");
  });

  it("registers the hotkey and navigates on press", async () => {
    $("body").append('<textarea id="tags">fox</textarea>');
    const { RandomPost, navigate } = await load();

    void RandomPost.instance;
    hotkeys.get("random")();

    expect(navigate).toHaveBeenCalledWith("/posts/random?tags=fox");
  });
});
