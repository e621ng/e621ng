export default class Logger {

  // Static methods
  // We want to be able to create custom loggers with different titles, but we also want
  // a simple static method for logging without needing to create a logger first.

  private static _instance: Logger = null;
  private static instantiate (): Logger {
    if (!Logger._instance) Logger._instance = new Logger("E6NG", null, [30, 60, 100]);
    return Logger._instance;
  }

  /**
   * Logs a message to the console with a title colored based on the input strings.
   * @param args The items to log, passed directly to console.log after the title.
   */
  public static log (...args: any[]): void {
    Logger.instantiate().log(...args);
  }

  public static loaded (value: string, exports = 0): void {
    if (!Logger.instantiate().isEnabled) return;

    const parts: string[] = [`%cE6NG%c Loaded: %c${value}%c`];
    if (exports) parts.push(`\n ⤷ Exports: ${exports}`);
    console.log(
      parts.join(""),
      "color:white;background:rgb(30,60,100);padding:1px 4px",
      "background:none;color:inherit;padding:unset;",
      "color:#6af",
      "color:inherit;",
    );
  }


  // Logger registry
  // Used to enable/disable loggers when the LStorage value changes.

  private static loggers: Logger[] = [];
  public static setEnabled (enabled: boolean): void {
    for (const logger of Logger.loggers)
      logger.isEnabled = enabled;
  }


  // Class methods

  private titleFormat: string;
  private titleStyles: string[];
  private isEnabled: boolean;

  /**
   * Creates a logger with a title colored based on the input strings.
   * @param controller The name of the controller.
   * @param action The name of the action, optional.
   */
  constructor (controller: string, action: string = null, color: [number, number, number] = null) {
    const c1 = color || Logger.stringToColor(controller),
      c2 = action ? Logger.stringToColor(action) : c1;

    if (action) {
      this.titleFormat = `%c${controller}%c:%c${action}%c`;
      this.titleStyles = [
        `color:white;background:rgb(${c1.join(",")});padding:1px 4px`,
        "background:none;color:inherit;padding:none;",
        `color:white;background:rgb(${c2.join(",")});padding:1px 4px`,
        "background:none;color:inherit;padding:none;",
      ];
    } else {
      this.titleFormat = `%c${controller}%c`;
      this.titleStyles = [
        `color:white;background:rgb(${c1.join(",")});padding:1px 4px`,
        "background:none;color:inherit;padding:none;",
      ];
    }

    this.isEnabled = window.localStorage.getItem("e6.debug") === "true";
    Logger.loggers.push(this);
  }

  /**
   * Proxy for console.log that prepends the logger's title to the log message.
   * If logging is disabled, this will be a no-op function.
   * @returns A function that can be used to log messages with the logger's title.
   */
  public get log (): (...args: any[]) => void {
    if (!this.isEnabled) return () => {};
    return console.log.bind(console, this.titleFormat, ...this.titleStyles);
  }

  /**
   * Proxy for console.error that prepends the logger's title to the error message.
   * If logging is disabled, this will be a no-op function.
   * @returns A function that can be used to log errors with the logger's title.
   */
  public get error (): (...args: any[]) => void {
    if (!this.isEnabled) return () => {};
    return console.error.bind(console, this.titleFormat, ...this.titleStyles);
  }

  /**
   * Converts a string to a color by hashing it and using the hash to generate RGB values.
   * The same input string will always produce the same output color.
   * @param str The input string to convert to a color.
   * @returns An array containing the RGB values.
   */
  static stringToColor (str: string): [number, number, number] {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      hash = str.charCodeAt(i) + ((hash << 5) - hash);
      hash |= 0;
    }

    const min = 0, max = 160;
    const r = min + (((hash >> 16) & 0xFF) % (max - min));
    const g = min + (((hash >> 8) & 0xFF) % (max - min));
    const b = min + ((hash & 0xFF) % (max - min));

    return [r, g, b];
  }
}
