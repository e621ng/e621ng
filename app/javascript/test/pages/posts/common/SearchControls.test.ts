import { describe, expect, it } from "vitest";

async function load () {
  const SearchControls = (await import("@/pages/posts/common/SearchControls")).default;
  const LStorage = (await import("@/utility/storage/Local")).default;
  return { SearchControls, LStorage };
}

describe("SearchControls", () => {
  it("toggles fullscreen and remembers it", async () => {
    document.body.innerHTML = "<button id=\"toggle-fullscreen\"></button>";
    const { SearchControls, LStorage } = await load();
    void SearchControls.instance;
    expect(document.body.dataset.stFullscreen).toBe("false");

    document.getElementById("toggle-fullscreen").click();
    expect(document.body.dataset.stFullscreen).toBe("true");
    expect(document.getElementById("toggle-fullscreen").classList.contains("active")).toBe(true);
    expect(LStorage.Posts.Fullscreen).toBe(true);
  });

  it("binds once, however often it is requested", async () => {
    document.body.innerHTML = "<button id=\"toggle-fullscreen\"></button>";
    const { SearchControls } = await load();
    expect(SearchControls.instance).toBe(SearchControls.instance);

    document.getElementById("toggle-fullscreen").click();
    expect(document.body.dataset.stFullscreen).toBe("true");
  });
});
