import StateUtils from "@/utility/StateUtils";
import Local from "@/utility/storage/Local";

/** Adds a toggle for the time display. Uses 2 elements & switches which is visible. */
class TimestampSwitch {

  /* ============================== */
  /* ===== Singleton Pattern ====== */
  /* ============================== */

  private static _instance: TimestampSwitch;
  public static get instance (): TimestampSwitch {
    if (!this._instance) this._instance = new TimestampSwitch();
    return this._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private fullTimestamp = false;

  private constructor () {
    if (TimestampSwitch._instance)
      throw new Error("TimestampSwitch is a singleton class. Use TimestampSwitch.instance to access the instance.");

    StateUtils.onReady(() => this.load());
  }


  /* ============================== */
  /* ========= Public API ========= */
  /* ============================== */

  public load () {
    if (!Local.Site.TimeSwitch) return;
    document.querySelectorAll("time.time-waiting").forEach((e) => this.initElement(e as HTMLTimeElement));
  }


  /* ============================== */
  /* ======== Class Methods ======= */
  /* ============================== */

  private initElement (element: HTMLTimeElement) {
    element.classList.remove("time-waiting");
    element.classList.add("time-switchable");

    // Happens if more content was loaded via AJAX, and the user already toggled the display style.
    if (this.fullTimestamp) this.swapElementText(element);

    if (!(element.parentElement instanceof HTMLAnchorElement)) {
      element.addEventListener("click", this.toggleDisplayedStyle.bind(this));
      element.classList.add("not-link");
    } else {
      const icon = document.createElement("span");
      icon.classList.add("time-switchable-icon");
      icon.innerText = "ⓘ";
      icon.title = "Toggle the time display.";
      icon.addEventListener("click", this.toggleDisplayedStyle.bind(this));
      element.parentElement.insertAdjacentElement("afterend", icon);
    }
  }

  private swapElementText (element: HTMLTimeElement) {
    const oldValue = element.textContent;
    element.textContent = element.title;
    element.title = oldValue;
  }

  private toggleDisplayedStyle () {
    this.fullTimestamp = !this.fullTimestamp;
    document.querySelectorAll("time.time-switchable").forEach((e) => {
      this.swapElementText(e as HTMLTimeElement);
    });
  }
}

export default TimestampSwitch.instance;
