/**
 * Offclick handler
 * Handles the logic for closing menus when clicking outside of them.
 * Usage:
 *   const offclickHandler = Offclick.register("#menu-button", ".menu-container", () => {
 *     // Close the menu
 *   });
 */
export default class Offclick {

  private registry: OffclickEntry[] = [];
  private globalDisabled = true;

  private static trigger (entry: OffclickEntry) {
    entry.callback();
    entry.disabled = true;
  }

  private constructor () {
    $(window).on("mouseup", (event) => {
      if (this.globalDisabled) return;
      if (event.button !== 0) return; // Only left click

      const target = $(event.target);

      for (const entry of this.registry) {
        if (entry.disabled) continue;

        if (target.closest(entry.menuSelector).length > 0 // Click inside the menu
            || target.is(entry.buttonSelector) // Click the button itself
            || target.parents(entry.buttonSelector).length > 0) // Click inside one of the button's children
          continue;

        Offclick.trigger(entry);
      }
    });
  }

  // If all entries are disabled, skip processing clicks.
  private recalculateGlobalDisabled () {
    this.globalDisabled = this.registry.every(entry => entry.disabled);
  }

  // Singleton pattern
  private static _instance: Offclick;
  private static get instance (): Offclick {
    if (typeof this._instance === "undefined")
      this._instance = new Offclick();
    return this._instance;
  }

  /**
   * Register a new offclick handler.
   * @param {string} buttonSelector The selector for the button that toggles the menu.
   * @param {string} menuSelector The selector for the menu container.
   * @param {Function} callback The callback to invoke when clicking outside the menu.
   * @param {boolean} disabled Does the menu start disabled or active?
   * @returns {Object} An object with a `disabled` property that can be toggled to enable/disable the offclick handler.
   */
  public static register (buttonSelector: string, menuSelector: string, callback: () => void, disabled: boolean = true): OffclickEntry {
    const entry: OffclickEntryItem = {
      buttonSelector: buttonSelector,
      menuSelector: menuSelector,
      callback: callback,
      get disabled () { return this._disabled; },
      set disabled (value: boolean) {
        this._disabled = value;
        Offclick.instance.recalculateGlobalDisabled();
      },
      _disabled: disabled,
    };

    this.instance.registry.push(entry);
    if (Offclick.instance.globalDisabled) Offclick.instance.globalDisabled = disabled;
    return entry;
  }

  public static unregister (entry: OffclickEntry, deactivate = true) {
    const i = this.instance.registry.indexOf(entry);
    if (i < 0) return false;

    this.instance.registry.splice(i, 1);
    if (deactivate) Offclick.trigger(entry);
    return true;
  }
}

export interface OffclickEntry {
  buttonSelector: string;
  menuSelector: string;
  callback: () => void;
  disabled: boolean;
}

interface OffclickEntryItem extends OffclickEntry {
  _disabled: boolean;
}
