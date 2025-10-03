/**
 * Offclick handler
 * Handles the logic for closing menus when clicking outside of them.
 * Usage:
 *   const offclickHandler = Offclick.register("#menu-button", ".menu-container", () => {
 *     // Close the menu
 *   });
 */
export default class Offclick {

  registry = [];
  globalDisabled = true;

  constructor () {
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
  static _instance = null;
  static get instance () {
    if (this._instance === null)
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
  static register (buttonSelector, menuSelector, callback) {
    const entry = {
      buttonSelector: buttonSelector,
      menuSelector: menuSelector,
      callback: callback,
      disabled: true, // Unused, but without it the linter complains
      _disabled: true, // Actual storage for the disabled state
    };

    Object.defineProperty(entry, "disabled", {
      get () { return this._disabled; },
      set (value) {
        this._disabled = value;
        Offclick.instance.recalculateGlobalDisabled();
      },
    });

    this.instance.registry.push(entry);
    return entry;
  }
}
