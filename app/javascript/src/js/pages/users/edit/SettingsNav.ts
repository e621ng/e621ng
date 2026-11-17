/**
 * Section switching and search on the settings page.
 * The server renders the active section from `?tab=`, so this only takes over once the page has loaded.
 */
export default class SettingsNav {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: SettingsNav | null = null;
  public static get instance (): SettingsNav {
    if (!SettingsNav._instance)
      SettingsNav._instance = new SettingsNav();
    return SettingsNav._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private readonly sections: HTMLElement[];
  private readonly links: HTMLAnchorElement[];
  private readonly select: HTMLSelectElement | null;
  private readonly search: HTMLInputElement | null;
  private readonly noResults: HTMLElement | null;
  private active = "";

  private constructor () {
    if (SettingsNav._instance)
      throw new Error("SettingsNav is a singleton class. Use SettingsNav.instance to access the instance.");

    const nav = document.querySelector<HTMLElement>(".settings-nav");
    this.sections = Array.from(document.querySelectorAll<HTMLElement>(".settings-section[data-section]"));
    this.links = Array.from(nav?.querySelectorAll<HTMLAnchorElement>(".settings-nav-list a[data-section]") ?? []);
    this.select = nav?.querySelector<HTMLSelectElement>(".settings-nav-select select") ?? null;
    this.search = nav?.querySelector<HTMLInputElement>("input[name='find']") ?? null;
    this.noResults = document.querySelector<HTMLElement>(".settings-no-results");
    if (!nav || this.sections.length === 0) return;

    this.active = this.sections.find((section) => !section.hidden)?.dataset.section ?? this.sections[0].dataset.section;

    for (const link of this.links)
      link.addEventListener("click", (event) => {
        event.preventDefault();
        this.navigate(link.dataset.section);
      });

    this.select?.addEventListener("change", () => this.navigate(this.select.value));

    this.search?.addEventListener("input", () => {
      const query = this.search.value.trim();
      this.filter(query);

      const url = new URL(window.location.href);
      if (query) {
        url.searchParams.set("find", query);
        url.searchParams.delete("tab");
      } else {
        url.searchParams.delete("find");
        this.setTabParam(url, this.active);
      }
      window.history.replaceState({}, "", url);
    });

    window.addEventListener("popstate", () => this.restoreFromURL());

    if (this.search?.value.trim()) this.filter(this.search.value.trim());
  }


  /* ============================== */
  /* ========= Public API ========= */
  /* ============================== */

  /** Shows a single section, clearing any search. Returns false for an unknown key. */
  public show (key: string): boolean {
    if (!this.sections.some((section) => section.dataset.section === key)) return false;

    this.active = key;
    if (this.search) this.search.value = "";
    this.resetFilter();

    for (const section of this.sections)
      section.hidden = section.dataset.section !== key;
    for (const link of this.links) {
      if (link.dataset.section === key) link.setAttribute("aria-current", "true");
      else link.removeAttribute("aria-current");
    }
    if (this.select) this.select.value = key;

    return true;
  }

  /** Shows the entries matching every term in the query, across all sections. An empty query shows the active section. */
  public filter (query: string): void {
    const terms = query.toLowerCase().split(" ").filter(Boolean);
    if (terms.length === 0) {
      this.show(this.active);
      return;
    }

    for (const link of this.links) link.removeAttribute("aria-current");

    let matches = 0;
    for (const section of this.sections) {
      section.hidden = false;

      const visibleGroups = new Set<string>();
      for (const entry of section.querySelectorAll<HTMLElement>("settings-entry")) {
        const keywords = entry.getAttribute("search") ?? "";
        const match = keywords !== "" && terms.every((term) => keywords.includes(term));
        entry.hidden = !match;
        if (!match) continue;

        matches++;
        const group = entry.getAttribute("group");
        if (group) visibleGroups.add(group);
      }

      for (const group of section.querySelectorAll<HTMLElement>("settings-group"))
        group.hidden = !visibleGroups.has(group.getAttribute("name") ?? "");
    }

    if (this.noResults) this.noResults.hidden = matches > 0;
  }


  /* ============================== */
  /* ======== Class Methods ======= */
  /* ============================== */

  private navigate (key: string): void {
    if (!this.show(key)) return;

    const url = new URL(window.location.href);
    url.searchParams.delete("find");
    this.setTabParam(url, key);
    window.history.pushState({}, "", url);
  }

  private restoreFromURL (): void {
    const params = new URLSearchParams(window.location.search);
    const find = params.get("find")?.trim();
    if (find) {
      if (this.search) this.search.value = find;
      this.filter(find);
      return;
    }

    const tab = params.get("tab");
    if (!tab || !this.show(tab)) this.show(this.sections[0].dataset.section);
  }

  // The first section is the default, so it does not need to be in the URL.
  private setTabParam (url: URL, key: string): void {
    if (key === this.sections[0].dataset.section) url.searchParams.delete("tab");
    else url.searchParams.set("tab", key);
  }

  private resetFilter (): void {
    for (const element of document.querySelectorAll<HTMLElement>(".settings-section settings-entry, .settings-section settings-group"))
      element.hidden = false;
    if (this.noResults) this.noResults.hidden = true;
  }
}
