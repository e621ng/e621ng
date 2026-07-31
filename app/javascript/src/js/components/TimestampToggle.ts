/** Adds a toggle for the time display. Uses 1 element & switches the title & innerText. */
export class TimestampToggle {
  public static init () {
    document.querySelectorAll("time").forEach((e) => new TimestampToggle(e));
  }

  private readonly titleBackup: string;
  constructor (
    public readonly element: HTMLTimeElement,
  ) {
    this.titleBackup = element.title;
    // if (element.parentElement?.tagName !== "A") {
    if (!(element.parentElement instanceof HTMLAnchorElement)) {
      this.element.addEventListener("click", this.toggleDisplayedStyle);
    } else {
      const icon = document.createElement("span");
      icon.innerText = "ⓘ";
      icon.style.cursor = "help";
      icon.title = "Toggles the time display.";
      icon.addEventListener("click", this.toggleDisplayedStyle);
      element.parentElement?.parentElement?.appendChild(icon);
    }
  }

  private readonly toggleDisplayedStyle = () => {
    if (!this.isToggleActive) {
      this.element.title = this.element.innerText;
      this.element.innerText = this.titleBackup;
    } else {
      this.element.innerText = this.element.title;
      this.element.title = this.titleBackup;
    }
  };

  /** Has the humanized text been swapped with the title, or not? */
  private get isToggleActive () { return this.element.title !== this.titleBackup; }
}

$(() => TimestampToggle.init());
