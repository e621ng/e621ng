import { describe, expect, it } from "vitest";

const CONTROLS = `
  <div id="advanced-search-container">
    <label data-advanced-search="inpool" data-state="unset"></label>
  </div>`;

function render ({ withControls = true } = {}): void {
  document.body.innerHTML = `
    <section class="post-search"><form><textarea name="tags">wolf inpool:true</textarea></form></section>
    ${withControls ? CONTROLS : ""}`;
}

async function load () {
  const SearchFilters = (await import("@/pages/posts/SearchFilters")).default;
  void SearchFilters.instance;
}

const inpool = () => document.querySelector<HTMLElement>("[data-advanced-search=inpool]");
const textarea = () => document.querySelector<HTMLTextAreaElement>("textarea[name=tags]");

describe("SearchFilters", () => {
  it("syncs the controls with the search on load", async () => {
    render();
    await load();
    expect(inpool().dataset.state).toBe("yes");
  });

  it("writes control changes back into the search", async () => {
    render();
    await load();

    inpool().click();
    expect(textarea().value).toContain("inpool:false");
    expect(inpool().dataset.state).toBe("no");
  });

  it("does nothing without the advanced search controls", async () => {
    render({ withControls: false });
    await load();
    expect(textarea().value).toBe("wolf inpool:true");
  });
});
