import Offclick, { OffclickEntry } from "./Offclick";

export default class UniversalTooltip<T extends HTMLElement> {
  private static instances: UniversalTooltip<HTMLElement>[] = [];
  private static allocatedIds = 0;
  private static getUniqueId () { return ++this.allocatedIds; }
  public static defaultHoldMS: number = 200;
  public static get isNeeded () { return !(matchMedia("(hover: hover)").matches); }
  public static init () {
    // if (!this.isNeeded) return;
    $(".st-universal-tooltip-parent").each((_i, e) => { new UniversalTooltip(e); });
  }

  private static extractHoldTime(e: HTMLElement) {
    const r = parseInt(e.getAttribute("hold-time"));
    if (isFinite(r)) return r;
    return UniversalTooltip.defaultHoldMS;
  }

  private timerId?: number;
  private offclick?: OffclickEntry;
  private _id?: number;
  private get id () { return this._id ??= UniversalTooltip.getUniqueId(); }
  private get selector () { return `${this.element.localName}${this.element.id.length > 0 ? "#" + this.element.id : ""}${this.element.className.length > 0 ? "." + this.element.className.replace(/\s/g, ".") : ""}`; }
  constructor (public readonly element: T, private readonly holdMS: number = UniversalTooltip.extractHoldTime(element)) {
    element.classList.add("st-universal-tooltip-parent");
    element.addEventListener("pointerdown", (e) => this.onDown(e));
    UniversalTooltip.instances.push(this);
  }

  private _tooltip?: HTMLElement;
  private get tooltip () {
    if (this._tooltip) { return this._tooltip; }
    this._tooltip = this.element.querySelector(".st-universal-tooltip");
    if (this._tooltip) {
      if (/^ut[0-9]+$/.test(this._tooltip.id)) {
        this._id = parseInt(/^ut[0-9]+$/.exec(this._tooltip.id)[1]!);
      } else {
        this._tooltip.setAttribute("tooltip-id", this.id.toString());
      }
      return this._tooltip;
    }
    this._tooltip = document.createElement("span");
    this._tooltip.className = "st-universal-tooltip";
    this._tooltip.id = `ut${this.id}`;
    this._tooltip.innerText = this.element.title;
    return this.element.appendChild(this._tooltip);
  }

  private onHeld (e: PointerEvent) {
    this.tooltip.setAttribute("activated", "activated");
    this.element.setAttribute("activated", "activated");
    this.offclick ??= Offclick.register(this.selector, `${this.tooltip.localName}${this.tooltip.id === `ut${this.id}` ? `#ut${this.id}` : `[tooltip-id=${this.id}]`}`, () => {
      this.tooltip.removeAttribute("activated");
      this.element.removeAttribute("activated");
    });
    this.offclick.disabled = false;
    this.timerId = undefined;
  }

  private onDown (e: PointerEvent) {
    if (this.timerId) return;
    this.timerId ??= setTimeout(() => this.onHeld(e), this.holdMS);
    this.element.addEventListener("pointercancel", (e) => this.onRelease(e));
  }

  private onRelease (e: PointerEvent) {
    if (!this.timerId) return;
    clearTimeout(this.timerId);
    this.timerId = undefined;
  }
}

$(() => UniversalTooltip.init());
