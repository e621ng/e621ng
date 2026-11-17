import { afterEach, describe, expect, it } from "vitest";

function render ({ active = "basic", find = "" } = {}): void {
  const section = (key: string, body: string) => `<section class="settings-section" id="settings-${key}" data-section="${key}" ${key === active ? "" : "hidden"}>${body}</section>`;
  const link = (key: string) => `<li><a href="?tab=${key}" data-section="${key}" ${key === active ? "aria-current=\"true\"" : ""}>${key}</a></li>`;

  document.body.innerHTML = `
    <nav class="settings-nav">
      <input type="search" name="find" value="${find}">
      <ul class="settings-nav-list">${link("basic")}${link("advanced")}</ul>
      <form class="settings-nav-select">
        <select name="tab"><option value="basic">Basic</option><option value="advanced">Advanced</option></select>
      </form>
    </nav>
    <form class="settings-content">
      ${section("basic", `
        <settings-group name="account">Account</settings-group>
        <settings-entry group="account" search="user account name">Name</settings-entry>
        <settings-group name="posts">Posts</settings-group>
        <settings-entry group="posts" search="posts display">Display</settings-entry>`)}
      ${section("advanced", `
        <settings-group name="privacy">Privacy</settings-group>
        <settings-entry group="privacy" search="favorites hide private privacy">Hide favorites</settings-entry>
        <settings-entry group="privacy" search="dmails filter">DMail filter</settings-entry>`)}
      <p class="settings-no-results" hidden>No settings found.</p>
    </form>`;
  (document.querySelector("select[name=tab]") as HTMLSelectElement).value = active;
}

async function load () {
  const SettingsNav = (await import("@/pages/users/edit/SettingsNav")).default;
  return SettingsNav.instance;
}

const section = (key: string) => document.getElementById(`settings-${key}`);
const link = (key: string) => document.querySelector<HTMLAnchorElement>(`.settings-nav-list a[data-section="${key}"]`);
const entry = (text: string) => Array.from(document.querySelectorAll<HTMLElement>("settings-entry")).find((e) => e.textContent === text);
const group = (name: string) => document.querySelector<HTMLElement>(`settings-group[name="${name}"]`);
const search = () => document.querySelector<HTMLInputElement>("input[name=find]");
const select = () => document.querySelector<HTMLSelectElement>("select[name=tab]");
const noResults = () => document.querySelector<HTMLElement>(".settings-no-results");

function type (value: string): void {
  search().value = value;
  search().dispatchEvent(new Event("input"));
}

describe("SettingsNav", () => {
  afterEach(() => window.history.replaceState({}, "", "/users/settings"));

  it("switches sections from the sidebar and pushes the tab to the URL", async () => {
    window.history.replaceState({}, "", "/users/settings");
    render();
    await load();
    const length = window.history.length;

    link("advanced").click();
    expect(section("advanced").hidden).toBe(false);
    expect(section("basic").hidden).toBe(true);
    expect(link("advanced").getAttribute("aria-current")).toBe("true");
    expect(link("basic").hasAttribute("aria-current")).toBe(false);
    expect(select().value).toBe("advanced");
    expect(window.location.search).toBe("?tab=advanced");
    expect(window.history.length).toBe(length + 1);

    link("basic").click();
    expect(window.location.search).toBe("");
  });

  it("switches sections from the select", async () => {
    render();
    await load();

    select().value = "advanced";
    select().dispatchEvent(new Event("change"));
    expect(section("advanced").hidden).toBe(false);
    expect(link("advanced").getAttribute("aria-current")).toBe("true");
  });

  it("filters entries and groups across sections without adding history", async () => {
    render();
    await load();
    const length = window.history.length;

    type("privacy");
    expect(section("basic").hidden).toBe(false);
    expect(section("advanced").hidden).toBe(false);
    expect(entry("Hide favorites").hidden).toBe(false);
    expect(entry("DMail filter").hidden).toBe(true);
    expect(entry("Name").hidden).toBe(true);
    expect(group("privacy").hidden).toBe(false);
    expect(group("account").hidden).toBe(true);
    expect(link("basic").hasAttribute("aria-current")).toBe(false);
    expect(noResults().hidden).toBe(true);
    expect(window.location.search).toBe("?find=privacy");
    expect(window.history.length).toBe(length);
  });

  it("requires every term to match", async () => {
    render();
    await load();

    type("posts privacy");
    expect(document.querySelectorAll("settings-entry:not([hidden])")).toHaveLength(0);
    expect(noResults().hidden).toBe(false);
  });

  it("returns to the active section when the search is cleared", async () => {
    render({ active: "advanced" });
    await load();

    type("posts");
    type("");
    expect(section("advanced").hidden).toBe(false);
    expect(section("basic").hidden).toBe(true);
    expect(entry("DMail filter").hidden).toBe(false);
    expect(group("privacy").hidden).toBe(false);
    expect(window.location.search).toBe("?tab=advanced");
  });

  it("applies a prefilled search on load", async () => {
    render({ find: "dmails" });
    await load();

    expect(entry("DMail filter").hidden).toBe(false);
    expect(entry("Hide favorites").hidden).toBe(true);
  });

  it("follows the URL on back and forward", async () => {
    render();
    await load();

    link("advanced").click();
    window.history.replaceState({}, "", "/users/settings");
    window.dispatchEvent(new PopStateEvent("popstate"));
    expect(section("basic").hidden).toBe(false);

    window.history.replaceState({}, "", "/users/settings?find=favorites");
    window.dispatchEvent(new PopStateEvent("popstate"));
    expect(search().value).toBe("favorites");
    expect(entry("Hide favorites").hidden).toBe(false);
    expect(entry("Name").hidden).toBe(true);
  });
});
