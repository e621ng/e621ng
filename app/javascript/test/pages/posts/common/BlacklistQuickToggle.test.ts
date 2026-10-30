import { beforeEach, describe, expect, it, vi } from "vitest";

const user = vi.hoisted(() => ({ blacklist: [] as string[] }));
vi.mock("@/models/CurrentUser", () => ({ default: user }));

function render (): void {
  document.body.innerHTML = `
    <ul>
      ${["wolf", "fox"].map((tag) => `
        <li class="tag-list-item" data-name="${tag}">
          <span class="tag-list-actions"><button data-tag="${tag}">Toggle</button></span>
        </li>`).join("")}
    </ul>`;
}

async function load () {
  const BlacklistQuickToggle = (await import("@/pages/posts/common/BlacklistQuickToggle")).default;
  void BlacklistQuickToggle.instance;
}

const item = (tag: string) => document.querySelector(`li[data-name="${tag}"]`);
const toggle = (tag: string) => document.querySelector<HTMLButtonElement>(`button[data-tag="${tag}"]`).click();

describe("BlacklistQuickToggle", () => {
  beforeEach(() => {
    user.blacklist = ["wolf", "fox rating:e"];
    vi.stubGlobal("confirm", vi.fn(() => true));
  });

  it("marks single-tag blacklist entries", async () => {
    render();
    await load();
    expect(item("wolf").classList.contains("blacklisted")).toBe(true);
    expect(item("fox").classList.contains("blacklisted")).toBe(false);
  });

  it("adds and removes tags after confirmation", async () => {
    render();
    await load();

    toggle("fox");
    expect(user.blacklist).toContain("fox");
    expect(item("fox").classList.contains("blacklisted")).toBe(true);

    toggle("wolf");
    expect(user.blacklist).not.toContain("wolf");
    expect(item("wolf").classList.contains("blacklisted")).toBe(false);
  });

  it("leaves the blacklist alone when cancelled", async () => {
    vi.stubGlobal("confirm", vi.fn(() => false));
    render();
    await load();

    toggle("fox");
    expect(user.blacklist).toEqual(["wolf", "fox rating:e"]);
  });

  it("re-marks the sidebar when the blacklist changes elsewhere", async () => {
    render();
    await load();

    user.blacklist = ["fox"];
    document.dispatchEvent(new CustomEvent("e621:blacklistUpdated", { detail: { blacklist: user.blacklist } }));
    expect(item("wolf").classList.contains("blacklisted")).toBe(false);
    expect(item("fox").classList.contains("blacklisted")).toBe(true);
  });
});
