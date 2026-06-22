import SVGIcon from "../../utility/SVGIcon";
import SearchQuery, { ORDER_ASC, ORDER_CUSTOM, ORDER_DESC, ORDER_VALUES, RATINGS } from "./SearchQuery";

const SORT_CUSTOM_ID = "advanced-search-sort-custom";

const TOGGLE_STATES = ["unset", "yes", "no"];
const TOGGLE_VALUES: Record<string, string> = { unset: "", yes: "true", no: "false" };
const TOGGLE_STATE_MAP: Record<string, string> = { "": "unset", "true": "yes", "false": "no" };


export default class SearchFilters {

  static initialize (): void {
    const $controls = $("#advanced-search-container") as JQuery<HTMLDivElement>;
    if (!$controls.length) return;

    $(".post-search").each((_index, element) => {
      const $textarea = $(element).find<HTMLTextAreaElement>("textarea[name=tags]").first();
      if (!$textarea.length) return;
      new SearchFilters($textarea, $controls);
    });
  }

  private $sortInputs: JQuery<HTMLInputElement>;
  private $inpoolToggle: JQuery<HTMLLabelElement>;
  private $ischildToggle: JQuery<HTMLLabelElement>;
  private $isparentToggle: JQuery<HTMLLabelElement>;
  private $ratingCheckboxes: JQuery<HTMLInputElement>;
  private ratingUpdateInProgress = false;

  constructor (private $textarea: JQuery<HTMLTextAreaElement>, private $controls: JQuery<HTMLDivElement>) {
    this.$sortInputs = this.$controls.find<HTMLInputElement>("[name='advanced-search-sort']");
    this.$inpoolToggle = this.$controls.find<HTMLLabelElement>("[data-advanced-search=inpool]").first();
    this.$ischildToggle = this.$controls.find<HTMLLabelElement>("[data-advanced-search=ischild]").first();
    this.$isparentToggle = this.$controls.find<HTMLLabelElement>("[data-advanced-search=isparent]").first();
    this.$ratingCheckboxes = this.$controls.find<HTMLInputElement>("[name='advanced-search-rating']");

    this.bindEvents();
    this.syncControls();
  }

  // Event binding

  private bindEvents (): void {
    if (this.$sortInputs.length) {
      this.$textarea.closest("form").on("submit", () => this.$sortInputs.prop("disabled", true));
    }

    this.$textarea.on("input", () => this.syncControls());
    this.$controls.on("change", "[name='advanced-search-sort']", () => this.updateOrder());
    this.$controls.on("click", ".sort-asc-btn", (event) => {
      event.preventDefault();
      event.stopPropagation();
      this.toggleAsc();
    });
    this.$controls.on("click", "[data-advanced-search=inpool]", (event) => this.updateInpool(event));
    this.$controls.on("click", "[data-advanced-search=ischild]", (event) => this.updateIschild(event));
    this.$controls.on("click", "[data-advanced-search=isparent]", (event) => this.updateIsparent(event));
    this.$ratingCheckboxes.on("change", () => this.updateRatings());
  }

  // Query - UI

  private syncControls (): void {
    const q = this.query;
    if (this.$sortInputs.length) this.setSortValue(q.order, q.direction);
    if (this.$inpoolToggle.length) this.setInpoolState(q.inpool);
    if (this.$ischildToggle.length) this.setIschildState(q.ischild);
    if (this.$isparentToggle.length) this.setIsparentState(q.isparent);
    this.syncRatingControls(q.ratings);
  }

  private setSortValue (value: string, direction: string): void {
    this.$controls.find("[name='advanced-search-sort']").prop("checked", false);
    this.$controls.find(".sort-asc-btn").remove();

    this.removeCustomSortOption();
    if (value === ORDER_CUSTOM) {
      this.addCustomSortOption("Custom", "pencil");
      this.$controls.find(`#${SORT_CUSTOM_ID}`).prop("checked", true);
      return;
    }

    const $found = this.$sortInputs.filter(`[value="${value}"]`);
    if ($found.length) {
      $found.prop("checked", true);
      if (ORDER_VALUES[value] && !ORDER_VALUES[value].flat) this.addAscButton($found.attr("id"), direction);
    } else if (value) {
      const entry = ORDER_VALUES[value];
      this.addCustomSortOption(entry ? entry.label : "Custom", entry ? entry.icon : "pencil");
      this.$controls.find(`#${SORT_CUSTOM_ID}`).prop("checked", true);
      if (entry && !entry.flat) this.addAscButton(SORT_CUSTOM_ID, direction);
    }
  }

  private setInpoolState (value: string): void {
    const state = TOGGLE_STATE_MAP[value] || "unset";
    this.$inpoolToggle.attr("data-state", state).attr("aria-label", `In pool: ${state}`);
  }

  private setIschildState (value: string): void {
    const state = TOGGLE_STATE_MAP[value] || "unset";
    this.$ischildToggle.attr("data-state", state).attr("aria-label", `Has parent: ${state}`);
  }

  private setIsparentState (value: string): void {
    const state = TOGGLE_STATE_MAP[value] || "unset";
    this.$isparentToggle.attr("data-state", state).attr("aria-label", `Has child: ${state}`);
  }

  private syncRatingControls (ratings: string): void {
    if (!this.$ratingCheckboxes.length || this.ratingUpdateInProgress) return;
    const selected = ratings || RATINGS.join("");
    this.$ratingCheckboxes.each((_index, element) => {
      const $rating = $(element);
      $rating.prop("checked", selected.includes($rating.val() as string));
    });
  }

  // UI - query

  private updateOrder (): void {
    const value = (this.$controls.find("[name='advanced-search-sort']:checked").val() as string) || "";
    this.query = this.query.withOrder(value, ORDER_DESC);
  }

  private toggleAsc (): void {
    const q = this.query;
    const newDirection = q.direction === ORDER_ASC ? ORDER_DESC : ORDER_ASC;
    this.query = q.withOrder(q.order, newDirection);
  }

  private updateInpool (event: JQuery.ClickEvent): void {
    const $el = $(event.currentTarget);
    const spanIndex = $el.find(".sto-tri").toArray().indexOf(event.target);
    let next: string;
    if (spanIndex >= 0) {
      next = TOGGLE_STATES[spanIndex];
    } else {
      const cur = TOGGLE_STATES.indexOf($el.attr("data-state") || "");
      next = TOGGLE_STATES[(cur < 0 ? 1 : cur + 1) % TOGGLE_STATES.length];
    }
    this.query = this.query.withInpool(TOGGLE_VALUES[next]);
  }

  private updateIschild (event: JQuery.ClickEvent): void {
    const $el = $(event.currentTarget);
    const spanIndex = $el.find(".sto-tri").toArray().indexOf(event.target);
    let next: string;
    if (spanIndex >= 0) {
      next = TOGGLE_STATES[spanIndex];
    } else {
      const cur = TOGGLE_STATES.indexOf($el.attr("data-state") || "");
      next = TOGGLE_STATES[(cur < 0 ? 1 : cur + 1) % TOGGLE_STATES.length];
    }
    this.query = this.query.withIschild(TOGGLE_VALUES[next]);
  }

  private updateIsparent (event: JQuery.ClickEvent): void {
    const $el = $(event.currentTarget);
    const spanIndex = $el.find(".sto-tri").toArray().indexOf(event.target);
    let next: string;
    if (spanIndex >= 0) {
      next = TOGGLE_STATES[spanIndex];
    } else {
      const cur = TOGGLE_STATES.indexOf($el.attr("data-state") || "");
      next = TOGGLE_STATES[(cur < 0 ? 1 : cur + 1) % TOGGLE_STATES.length];
    }
    this.query = this.query.withIsparent(TOGGLE_VALUES[next]);
  }

  private updateRatings (): void {
    const checked = this.$ratingCheckboxes
      .filter(":checked")
      .map((_index, element) => element.value)
      .get()
      .sort((a, b) => RATINGS.indexOf(a) - RATINGS.indexOf(b));
    this.ratingUpdateInProgress = true;
    try {
      this.query = this.query.withRatings(checked);
    } finally {
      this.ratingUpdateInProgress = false;
    }
  }

  // DOM helpers

  private addCustomSortOption (label: string, iconName: string): void {
    const svgEl = iconName ? SVGIcon.render(iconName) : null;
    const icon = svgEl ? svgEl.outerHTML : "";
    this.$sortInputs.first().closest(".ssc-body").append(
      `<input type="radio" id="${SORT_CUSTOM_ID}" name="advanced-search-sort" value="${ORDER_CUSTOM}">`
      + `<label for="${SORT_CUSTOM_ID}">${icon}${label}</label>`,
    );
  }

  private removeCustomSortOption (): void {
    this.$controls.find(`#${SORT_CUSTOM_ID}, label[for='${SORT_CUSTOM_ID}']`).remove();
  }

  private addAscButton (inputId: string | undefined, direction: string): void {
    if (!inputId) return;
    const $label = this.$controls.find(`label[for='${inputId}']`);
    const iconEl = SVGIcon.render(direction === ORDER_ASC ? "arrow_up" : "arrow_down");
    $("<button>")
      .attr({
        "type": "button",
        "aria-label": "Toggle ascending",
      })
      .addClass("sort-asc-btn")
      .toggleClass("active", direction === ORDER_ASC)
      .append(iconEl || "")
      .appendTo($label);
  }

  // Textarea accessor

  private get query (): SearchQuery {
    return new SearchQuery(String(this.$textarea.val() ?? ""));
  }

  private set query (q: SearchQuery) {
    this.$textarea.val(q.toString()).trigger("input");
  }
}

$(() => SearchFilters.initialize());
