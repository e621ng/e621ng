export default class Logger {

  // Static methods
  // We want to be able to create custom loggers with different titles, but we also want
  // a simple static method for logging without needing to create a logger first.

  private static _instance: Logger = null;

  /**
   * Logs a message to the console with a title colored based on the input strings.
   * @param args The items to log, passed directly to console.log after the title.
   */
  public static log (...args: any[]): void {
    if (!Logger._instance) Logger._instance = new Logger("E6NG", null, [30, 60, 100]);
    Logger._instance.log(...args);
  }

  public static loaded (value: string): void {
    console.log(`\x1B[97;48;2;${30};${60};${100}mE6NG\x1B[m Loaded: \x1B[94m${value}\x1B[m`);
  }


  // Class methods

  private title: string;

  /**
   * Creates a logger with a title colored based on the input strings.  
   * @param controller The name of the controller.
   * @param action The name of the action, optional.
   */
  constructor (controller: string, action: string = null, color: [number, number, number] = null) {
    const c1 = color || Logger.stringToColor(controller),
      c2 = action ? Logger.stringToColor(action) : c1;

    this.title = [
      `\x1B[97;48;2;${c1[0]};${c1[1]};${c1[2]}m`,
      controller,
      (action ? ("\x1B[0m" + ":" + `\x1B[97;48;2;${c2[0]};${c2[1]};${c2[2]}m` + action) : ""),
      "\x1B[0m",
    ].join("");
  }

  /**
   * Checks if logging is enabled by looking for a specific key in localStorage.
   * Deliberately not using LStorage here to avoid dependencies.
   * @returns True if logging is enabled, false otherwise.
   */
  public get isEnabled (): boolean {
    return window.localStorage.getItem("e6.debug") === "true";
  }

  /**
   * Logs a message to the console with a title colored based on the input strings.
   * @param args The items to log, passed directly to console.log after the title.
   */
  public log (...args: any[]): void {
    if (!this.isEnabled) return;
    console.log(this.title, ...args);
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
