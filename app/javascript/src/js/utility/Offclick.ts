/**
 * Offclick handler
 * Handles the logic for closing menus when clicking outside of them.
 * Usage:
 *   const offclickHandler = Offclick.register("#menu-button", ".menu-container", () => {
 *     // Close the menu
 *   });
 */
export default class Offclick {

  registry: OffclickEntry[] = [];
  globalDisabled = true;

  constructor () {
    $(window).on("pointerup", (event) => {
      if (this.globalDisabled) return;
      if ((event.originalEvent as PointerEvent).button !== 0) return;

      const target = $(event.target);

      for (const entry of this.registry) {
        if (entry.disabled) continue;

        if (target.closest(entry.menuSelector).length > 0 // Click inside the menu
            || target.is(entry.buttonSelector) // Click the button itself
            || target.parents(entry.buttonSelector).length > 0) // Click inside one of the button's children
          continue;

        entry.callback();
        entry.disabled = true;
      }
    });
  }

  // If all entries are disabled, skip processing clicks.
  recalculateGlobalDisabled () {
    this.globalDisabled = this.registry.every(entry => entry.disabled);
  }

  // Singleton pattern
  static _instance: Offclick;
  static get instance (): Offclick {
    if (typeof this._instance === "undefined")
      this._instance = new Offclick();
    return this._instance;
  }

  /**
   * Register a new offclick handler.
   * @param {string} buttonSelector The selector for the button that toggles the menu.
   * @param {string} menuSelector The selector for the menu container.
   * @param {Function} callback The callback to invoke when clicking outside the menu.
   * @returns {Object} An object with a `disabled` property that can be toggled to enable/disable the offclick handler.
   */
  static register (buttonSelector: string, menuSelector: string, callback: () => void): OffclickEntry {
    const entry = new OffclickEntry(buttonSelector, menuSelector, callback);
    this.instance.registry.push(entry);
    return entry;
  }
}

export class OffclickEntry {

  private _disabled = true;

  constructor (
    public readonly buttonSelector: string,
    public readonly menuSelector: string,
    public readonly callback: () => void,
  ) {}

  get disabled () {
    return this._disabled;
  }

  set disabled (value: boolean) {
    this._disabled = value;
    Offclick.instance.recalculateGlobalDisabled();
  }

  public trigger () {
    if (this.disabled) return;
    this.callback();
    this.disabled = true;
  }
}
