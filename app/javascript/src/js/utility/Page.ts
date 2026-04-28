export default class Page {

  static _controller: string;

  static _action: string;

  static _init (): void {
    const data = document.body.dataset;
    this._controller = data.controller;
    this._action = data.action;

    if (this._controller == "posts" && this._action == "show-seq")
      this._action = "show";
  }

  /** @returns {string} Controller for the current page */
  static get Controller (): string {
    if (!this._controller) this._init();
    return this._controller;
  }

  /** @returns {string} Action for the current page */
  static get Action (): string {
    if (!this._action) this._init();
    return this._action;
  }

  /**
   * Checks if the current page matches the provided parameters.
   * If both params are provided, checks against both of them.
   * If only the controller is provided, action is ignored.
   * @param {string} controller Controller to match against
   * @param {string} action Action to match against
   * @returns {boolean} True if the params match, false otherwise
   */
  static matches (controller: string, action: string = ""): boolean {
    if (!this._controller) this._init();

    if (action)
      return this._controller == controller && this._action == action;
    return this._controller == controller;
  }
}
