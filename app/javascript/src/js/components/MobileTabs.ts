/**
 * Tab row that splits a page into panels on mobile. On desktop the row is hidden and every panel shows.
 * Markup is rendered by MobileTabsComponent; the initial state comes from the server, so nothing flashes.
 */
export default class MobileTabs {

  private static instances = new WeakMap<HTMLElement, MobileTabs>();

  /** Returns the tab switcher for the given tablist, creating it on first use. */
  public static init (root: HTMLElement): MobileTabs {
    let instance = MobileTabs.instances.get(root);
    if (!instance) {
      instance = new MobileTabs(root);
      MobileTabs.instances.set(root, instance);
    }
    return instance;
  }

  public static initAll (): MobileTabs[] {
    return Array.from(document.querySelectorAll<HTMLElement>(".mobile-tabs[role=tablist]"), (root) => MobileTabs.init(root));
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private readonly tabs: HTMLButtonElement[];
  private readonly listeners: ((key: string) => void)[] = [];
  private _active: string;

  private constructor (root: HTMLElement) {
    this.tabs = Array.from(root.querySelectorAll<HTMLButtonElement>("button[role=tab][data-tab]"));
    this._active = this.tabs.find((tab) => tab.getAttribute("aria-selected") === "true")?.dataset.tab ?? this.tabs[0]?.dataset.tab ?? "";

    root.addEventListener("click", (event) => {
      const tab = (event.target as HTMLElement).closest<HTMLButtonElement>("button[role=tab][data-tab]");
      if (tab && this.tabs.includes(tab)) this.switchTo(tab.dataset.tab);
    });
    root.addEventListener("keydown", (event) => this.handleKeydown(event));
  }


  /* ============================== */
  /* ========= Public API ========= */
  /* ============================== */

  public get active (): string {
    return this._active;
  }

  /** Activates the tab with the given key. Returns false if no such tab exists. */
  public switchTo (key: string): boolean {
    if (!this.tabs.some((tab) => tab.dataset.tab === key)) return false;
    if (key === this._active) return true;

    this._active = key;
    for (const tab of this.tabs) {
      const selected = tab.dataset.tab === key;
      tab.setAttribute("aria-selected", String(selected));
      tab.tabIndex = selected ? 0 : -1;

      const panelID = tab.getAttribute("aria-controls");
      if (panelID) document.getElementById(panelID)?.toggleAttribute("data-active", selected);
    }

    for (const listener of this.listeners) listener(key);
    return true;
  }

  /** Called with the new key whenever the active tab changes. */
  public onChange (listener: (key: string) => void): this {
    this.listeners.push(listener);
    return this;
  }


  /* ============================== */
  /* ======== Class Methods ======= */
  /* ============================== */

  // WAI-ARIA tabs pattern, automatic activation
  private handleKeydown (event: KeyboardEvent): void {
    const current = this.tabs.findIndex((tab) => tab.dataset.tab === this._active);
    let next: number;
    switch (event.key) {
      case "ArrowLeft": next = (current - 1 + this.tabs.length) % this.tabs.length; break;
      case "ArrowRight": next = (current + 1) % this.tabs.length; break;
      case "Home": next = 0; break;
      case "End": next = this.tabs.length - 1; break;
      default: return;
    }

    event.preventDefault();
    this.switchTo(this.tabs[next].dataset.tab);
    this.tabs[next].focus();
  }
}
