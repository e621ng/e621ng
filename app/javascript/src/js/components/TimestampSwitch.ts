/** Adds a toggle for the time display. Uses 2 elements & switches which is visible. */
export class TimestampSwitch {
  public static init () {
    document.querySelectorAll("time").forEach((e) => new TimestampSwitch(e));
  }

  public readonly inverseElement: HTMLTimeElement;
  constructor (
    public readonly element: HTMLTimeElement,
  ) {
    this.inverseElement = document.createElement("time");
    this.inverseElement.outerHTML = element.outerHTML;
    this.inverseElement.title = element.innerText ?? element.innerHTML;
    this.inverseElement.innerText = element.title;
    this.inverseElement.style.display = "none";
    // if (element.parentElement?.tagName !== "A") {
    if (!(element.parentElement instanceof HTMLAnchorElement)) {
      this.element.addEventListener("click", this.toggleDisplayedStyle);
      this.inverseElement.addEventListener("click", this.toggleDisplayedStyle);
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
    if (this.inverseElement.style.display === "none") {
      this.element.style.display = "none";
      this.inverseElement.style.removeProperty("display");
    } else {
      this.element.style.removeProperty("display");
      this.inverseElement.style.display = "none";
    }
  };
}

$(() => TimestampSwitch.init());
