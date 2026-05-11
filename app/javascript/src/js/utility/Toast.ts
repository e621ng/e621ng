import Logger from "./Logger";
import SVGIcon from "./SVGIcon";
import TaskQueue from "./TaskQueue";

// 🍞🍞🍞
export default class ToastManager {

  private static Logger = new Logger("ToastManager");

  private static _registry: Record<number, Toast> = {};
  public static register (toast: Toast) { ToastManager._registry[toast.hash] = toast; }
  public static unregister (toast: Toast) { delete ToastManager._registry[toast.hash]; }

  public static get (message: string): Toast | null {
    const id = ToastUtilities.getStringHash(message);
    return ToastManager._registry[id] || null;
  }


  /* ==================== */
  /* ==== Public API ==== */
  /* ==================== */

  /**
   * Creates a new toast message.
   * If a toast with the same message already exists, it will update the existing toast's settings and increment its counter instead of creating a new one.
   * @param message The message to display in the toast.
   * @param options Optional settings for the toast, such as type and timeout.
   * @returns The created or updated toast instance.
   */
  public static create (message: string, options: ToastOptions = {}): Toast {
    // Try to find an existing toast with the same message.
    const id = ToastUtilities.getStringHash(message);
    ToastManager.Logger.log(`Creating toast with id ${id}`);

    const existingToast = ToastManager._registry[id];
    if (existingToast) {
      ToastManager.Logger.log(` - Found with id ${existingToast.hash}`);
      existingToast.counter += 1;

      // Update the existing toast with the new settings
      if (options.type) existingToast.type = options.type;
      if (options.timeout !== undefined) existingToast.timeout = options.timeout;
      else existingToast.resetTimeout(); // Reset auto-dismiss

      // Existing toast might have been dismissed
      existingToast.isVisible = true;

      return existingToast;
    }

    const toast = new Toast(message, options);
    ToastManager.Logger.log(` - Registered with id ${toast.hash}`);
    return toast;
  }

  /**
   * Dismisses toasts with the given messages.
   * If a toast with a specified message does not exist, it will be ignored.
   * @param messages One or more messages corresponding to the toasts to dismiss.
   */
  public static dismiss (...messages: string[]) {
    for (const message of messages) {
      const toast = ToastManager.get(message);
      if (toast) {
        ToastManager.Logger.log(`Dismissing toast with id ${toast.hash}`);
        toast.dismiss(true);
      }
    }
  }


  /* ==================== */
  /* == Short-Form API == */
  /* ==================== */

  public static notice (message: string, permanent: boolean = false): void {
    ToastManager.create(message, { type: "notice", timeout: permanent ? 0 : undefined });
  }

  public static alert (message: string): void {
    ToastManager.create(message, { type: "alert", timeout: 0 });
  }


  /* ==================== */
  /* == Initialization == */
  /* ==================== */

  public static bootstrap () {
    this.bootstrapRailsMessages();
    this.bootstrapHotkeys();
    this.bootstrapEventListeners();
  }

  private static bootstrapRailsMessages () {
    // Note that these messages are not registered, and thus will not be deduplicated.
    // They also can't be updated the same way as regular toasts.
    $("#toast-container .toast").each((_index, element) => {
      const $element = $(element);

      async function dismiss () {
        $element.addClass("toast-fadeout");
        await TaskQueue.sleep(250);
        $element.remove();
      }

      $element.find(".toast-close").show().on("click", dismiss);
      if (!$element.hasClass("toast-alert")) setTimeout(dismiss, 3000);
    });
  }

  private static bootstrapHotkeys () {
    $(window).on("keydown", (event) => {
      if (event.key !== "Escape") return;
      $("#toast-container .toast:not(.toast-fadeout) .toast-close").first().trigger("click");
    });
  }

  private static bootstrapEventListeners () {
    $(window).on("danbooru:notice", (_event, message) => {
      ToastManager.create(message);
    });
    $(window).on("danbooru:error", (_event, message) => {
      ToastManager.get("Updating post...")?.dismiss(true);
      ToastManager.get("Updating posts...")?.dismiss(true);
      ToastManager.create(message, { type: "alert" });
    });
  }
}

// 🍞
export class Toast {

  // Attachment point for all toasts. Lazily initialized on first access.
  private static _container: JQuery<HTMLElement>;
  private static get container (): JQuery<HTMLElement> {
    if (!this._container)
      this._container = $("#toast-container");
    return this._container;
  }

  private _message: string;
  private _messageHash: number;
  private _type: FlashType;
  private _counter = 1;
  private _timeout: number;
  private _isVisible = true;

  private timeoutId: number | null = null;

  private $element: JQuery<HTMLElement>;
  private $content: JQuery<HTMLElement>;
  private $counter: JQuery<HTMLElement>;

  constructor (message: string, options: ToastOptions = {}) {
    this._message = message;
    this._messageHash = ToastUtilities.getStringHash(message);

    const { type = "notice", timeout = 3 } = options;
    this._type = type;
    this._timeout = timeout;

    this.render();
  }

  public get isVisible (): boolean { return this._isVisible; }
  public set isVisible (value: boolean) {
    if (value && !this._isVisible) this.render();
    else if (!value && this._isVisible) this.dismiss();
  }

  /**
   * Gets or sets the message content of the toast.
   * Updating the message will also update the displayed content if the toast is already rendered.
   * @returns The current message of the toast.
   */
  public get message (): string { return this._message; }
  public set message (value: string) {
    ToastManager.unregister(this);
    this._message = value;
    this._messageHash = ToastUtilities.getStringHash(value);
    ToastManager.register(this);
    if (!this.isVisible) return;
    this.$content.html(value);
  }

  /**
   * Gets the hash of the toast's message, used for identifying toasts with the same content.
   * @returns The hash of the toast's message.
   */
  public get hash (): number { return this._messageHash; }

  /**
   * Gets or sets the type of the toast, which determines its styling.
   * Valid types are the supported `FlashType` variants, such as "notice" and "alert".
   * Updating the type will also update the styling of the toast if it is already rendered.
   * @returns The current type of the toast.
   */
  public get type (): FlashType { return this._type; }
  public set type (value: FlashType) {
    if (this.isVisible) {
      this.$element
        .removeClass(`toast-${this._type}`)
        .addClass(`toast-${value}`)
        .attr("role", value === "alert" ? "alert" : "status");
    }
    this._type = value;
  }

  /**
   * Gets or sets the timeout duration of the toast in seconds.
   * A value of 0 means the toast will not auto-dismiss.
   * Updating the timeout will reset the auto-dismiss timer if the toast is already rendered.
   * @returns The current timeout duration of the toast in seconds.
   */
  public get timeout (): number { return this._timeout; }
  public set timeout (value: number) {
    this._timeout = value;

    if (this.timeoutId !== null) {
      window.clearTimeout(this.timeoutId);
      this.timeoutId = null;
    }

    if (!this.isVisible) return;

    if (value > 0)
      this.timeoutId = window.setTimeout(() => this.dismiss(), value * 1000);
  }

  public resetTimeout () {
    if (!this.isVisible) return;
    if (this.timeoutId !== null) {
      window.clearTimeout(this.timeoutId);
      this.timeoutId = null;
    }
    if (this._timeout > 0)
      this.timeoutId = window.setTimeout(() => this.dismiss(), this._timeout * 1000);
  }

  /**
   * Gets or sets the counter value of the toast.
   * This is used to indicate how many times the same message has been triggered.
   * Updating the counter will also update the displayed counter if the toast is already rendered.
   * @returns The current counter value of the toast.
   */
  public get counter (): number { return this._counter; }
  public set counter (value: number) {
    this._counter = value;
    if (!this.isVisible) return;
    this.$counter.text(value.toString());
    this.$element.attr("data-counter", value.toString());
  }

  /**
   * Rewrites the toast's message and optionally updates its type and timeout settings.
   * @param message The new message to display in the toast.
   * @param options Optional settings to update the toast's type and timeout.
   */
  public rewrite (message: string, options: ToastOptions = {}) {
    this.message = message;
    if (options.type) this.type = options.type;
    if (options.timeout !== undefined) this.timeout = options.timeout;
    else this.resetTimeout();
  }

  /**
   * Renders the toast element and appends it to the container. If the element already exists, it simply returns it.
   * @returns The jQuery element representing the toast.
   */
  public render (): JQuery<HTMLElement> {
    if (this.$element) return this.$element;

    this.$element = $("<div>")
      .addClass(`toast toast-${this.type}`)
      .attr({
        "role": this.type === "alert" ? "alert" : "status",
        "data-counter": this.counter.toString(),
      });

    this.$content = $("<span>")
      .addClass("toast-message")
      .html(this.message)
      .appendTo(this.$element);

    this.$counter = $("<span>")
      .addClass("toast-counter")
      .text(this.counter.toString())
      .appendTo(this.$element);

    $("<button>")
      .addClass("toast-close")
      .attr({
        "type": "button",
        "aria-label": "Close notification",
      })
      .html(SVGIcon.render("times")?.outerHTML || "x")
      .appendTo(this.$element)
      .on("click", () => this.dismiss());

    if (this.timeout > 0)
      this.timeoutId = window.setTimeout(() => this.dismiss(), this.timeout * 1000);

    ToastManager.register(this);
    this._isVisible = true;
    Toast.container?.append(this.$element);
    return this.$element;
  }

  private isDismissing = false;

  /**
   * Dismisses the toast, removing it from the DOM and cleaning up references.
   */
  public async dismiss (immediate: boolean = false): Promise<void> {
    if (this.isDismissing) return;
    this.isDismissing = true;

    // Unregister immediately to avoid swallowing new toasts with the same message while this one is fading out.
    ToastManager.unregister(this);

    if (this.timeoutId !== null) {
      window.clearTimeout(this.timeoutId);
      this.timeoutId = null;
    }

    if (!immediate && this.$element) {
      this.$element.addClass("toast-fadeout");
      await TaskQueue.sleep(250);
    }

    if (this.$element) // May not exist if dismissed again before animation completes
      this.$element.remove();
    this.$element = null;
    this.$content = null;
    this.$counter = null;
    this._isVisible = false;

    this.isDismissing = false;
  }
}

export class ToastUtilities {
  /**
   * Generates a hash code for a given string.
   * This is used to identify toasts with the same message for deduplication purposes.
   * @param str The string to hash.
   * @param seed An optional seed value for the hash function.
   * @returns A numeric hash code for the given string.
   */
  public static getStringHash (str: string, seed = 0): number {
    let h1 = 0xdeadbeef ^ seed, h2 = 0x41c6ce57 ^ seed;
    for (let i = 0, ch: number; i < str.length; i++) {
      ch = str.charCodeAt(i);
      h1 = Math.imul(h1 ^ ch, 2654435761);
      h2 = Math.imul(h2 ^ ch, 1597334677);
    }
    h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507);
    h1 ^= Math.imul(h2 ^ (h2 >>> 13), 3266489909);
    h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507);
    h2 ^= Math.imul(h1 ^ (h1 >>> 13), 3266489909);

    return (4294967296 * (2097151 & h2)) + (h1 >>> 0);
  }
}

interface ToastOptions {
  /** The type of flash message. */
  type?: FlashType;

  /** The timeout duration in seconds. Set to 0 for a permanent toast. */
  timeout?: number;
}

type FlashType = "notice" | "alert" | "info";

export type ToastInitializer = (message: string, options?: ToastOptions) => void;
