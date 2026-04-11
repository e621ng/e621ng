export default class Logger {

  constructor (controller, action) {
    const c1 = Logger.stringToColor(controller),
      c2 = action ? Logger.stringToColor(action) : c1;

    this.title = [
      `\x1B[97;48;2;${c1[0]};${c1[1]};${c1[2]}m`,
      controller,
      (action ? ("\x1B[0m" + ":" + `\x1B[97;48;2;${c2[0]};${c2[1]};${c2[2]}m` + action) : ""),
      "\x1B[0m",
    ].join("");
  }

  get isEnabled () {
    return window.localStorage.getItem("e6.debug") === "true";
  }

  log (...args) {
    if (!this.isEnabled) return;
    console.log(this.title, ...args);
  }

  static _instance = null;
  static log (...args) {
    if (!Logger._instance) Logger._instance = new Logger("E6NG");
    Logger._instance.log(...args);
  }

  static stringToColor (str) {
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
