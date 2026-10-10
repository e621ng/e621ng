import SVGIcon from "../../utility/SVGIcon";
import SearchQuery, {
  MEDIA_ALL, MEDIA_LETTERS, ORDER_ASC, ORDER_CUSTOM, ORDER_DESC, ORDER_VALUES, RATINGS,
  SOUND_BOTH, SOUND_NO_SOUND, SOUND_ONLY, SOUND_WARNING_ONLY,
} from "./SearchQuery";

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
  private $mediaCheckboxes: JQuery<HTMLInputElement>;
  private $soundCheckboxes: JQuery<HTMLInputElement>;
  private ratingUpdateInProgress = false;
  private mediaUpdateInProgress = false;
  private soundUpdateInProgress = false;

  constructor (private $textarea: JQuery<HTMLTextAreaElement>, private $controls: JQuery<HTMLDivElement>) {
    this.$sortInputs = this.$controls.find<HTMLInputElement>("[name='advanced-search-sort']");
    this.$inpoolToggle = this.$controls.find<HTMLLabelElement>("[data-advanced-search=inpool]").first();
    this.$ischildToggle = this.$controls.find<HTMLLabelElement>("[data-advanced-search=ischild]").first();
    this.$isparentToggle = this.$controls.find<HTMLLabelElement>("[data-advanced-search=isparent]").first();
    this.$ratingCheckboxes = this.$controls.find<HTMLInputElement>("[name='advanced-search-rating']");
    this.$mediaCheckboxes = this.$controls.find<HTMLInputElement>("[name='advanced-search-media']");
    this.$soundCheckboxes = this.$controls.find<HTMLInputElement>("[name='advanced-search-sound']");

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
    this.$mediaCheckboxes.on("change", () => this.updateMediaTypes());
    this.$soundCheckboxes.on("change", (event) => this.updateSound(event));
  }

  // Query - UI

  private syncControls (): void {
    const q = this.query;
    if (this.$sortInputs.length) this.setSortValue(q.order, q.direction);
    if (this.$inpoolToggle.length) this.setInpoolState(q.inpool);
    if (this.$ischildToggle.length) this.setIschildState(q.ischild);
    if (this.$isparentToggle.length) this.setIsparentState(q.isparent);
    this.syncRatingControls(q.ratings);
    this.syncMediaControls(q.media, q.mediaCustom);
    this.syncSoundControls(q.sound);
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

  private syncMediaControls (media: string, isCustom: boolean): void {
    if (!this.$mediaCheckboxes.length || this.mediaUpdateInProgress) return;
    const hasOwnedSelection = media !== MEDIA_ALL;
    const showIndeterminate = isCustom && !hasOwnedSelection;

    this.$mediaCheckboxes.each((_index, element) => {
      const $media = $(element);
      $media.prop("indeterminate", showIndeterminate);
      $media.prop("checked", !showIndeterminate && (!hasOwnedSelection || media.includes($media.val() as string)));
    });
    this.$mediaCheckboxes.first().closest(".ssc-body").toggleClass("ssc-media-custom", isCustom);
  }

  private soundCheckbox (value: string): JQuery<HTMLInputElement> {
    return this.$soundCheckboxes.filter(`[value='${value}']`);
  }

  /**
   * Sound warning is only ever shown for a sound-bearing state (Sound + Warning,
   * Sound only, or Warning only) — collapsed otherwise. Hiding via the native
   * `hidden` property (rather than a CSS class) keeps it out of layout entirely, so
   * collapsing/expanding never reflows the sibling Media type column.
   */
  private syncSoundControls (sound: string): void {
    if (!this.$soundCheckboxes.length || this.soundUpdateInProgress) return;

    const noSound = sound === SOUND_NO_SOUND;
    const hasSound = sound === SOUND_BOTH || sound === SOUND_ONLY;
    const hasWarning = sound === SOUND_BOTH || sound === SOUND_WARNING_ONLY;
    const expanded = hasSound || hasWarning;

    this.soundCheckbox("no_sound").prop("checked", noSound);
    this.soundCheckbox("sound").prop("checked", hasSound);

    const $warning = this.soundCheckbox("sound_warning");
    $warning.prop("checked", hasWarning);
    $warning.prop("hidden", !expanded);
    $warning.next("label").prop("hidden", !expanded);
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

  private updateMediaTypes (): void {
    const checked = this.$mediaCheckboxes
      .filter(":checked")
      .map((_index, element) => element.value)
      .get()
      .sort((a, b) => MEDIA_LETTERS.indexOf(a) - MEDIA_LETTERS.indexOf(b));

    this.mediaUpdateInProgress = true;
    let query: SearchQuery;
    try {
      query = this.query.withMediaTypes(checked);
      this.query = query;
    } finally {
      this.mediaUpdateInProgress = false;
    }

    // Mirrors Rating: don't fight the user's own action. All four unchecked and all
    // four checked both serialize to the same (empty) query, so a normal resync here
    // would immediately re-check boxes the user just unchecked. Only skip the resync
    // when the result is genuinely unrestricted (mediaCustom false) — if custom media
    // content still remains, we still need to sync to that custom-only representation.
    if (checked.length === 0 && !query.mediaCustom) {
      this.$mediaCheckboxes.prop("indeterminate", false);
      this.$mediaCheckboxes.first().closest(".ssc-body").removeClass("ssc-media-custom");
      return;
    }

    this.syncMediaControls(query.media, query.mediaCustom);
  }

  /**
   * Applies the mutual-exclusion / default-warning-on rules from a single change
   * event before reading the final tri-state and writing the query:
   * - checking No sound clears Sound and Sound warning;
   * - checking Sound clears No sound, and defaults Sound warning on if it wasn't
   *   already checked (Sound warning keeps its own state otherwise — e.g. checking
   *   Sound from "Sound warning only" leaves Warning checked, landing on "both").
   * Unchecking either Sound or Sound warning needs no forced side effect: reading
   * the resulting tri-state as-is already reproduces every documented transition
   * (see the interaction table in the Sound plan).
   */
  private updateSound (event: JQuery.ChangeEvent): void {
    const target = event.target as HTMLInputElement;
    const $noSound = this.soundCheckbox("no_sound");
    const $sound = this.soundCheckbox("sound");
    const $warning = this.soundCheckbox("sound_warning");

    if (target === $noSound.get(0) && target.checked) {
      $sound.prop("checked", false);
      $warning.prop("checked", false);
    } else if (target === $sound.get(0) && target.checked) {
      $noSound.prop("checked", false);
      if (!$warning.prop("checked")) $warning.prop("checked", true);
    }

    const noSound = $noSound.prop("checked");
    const hasSound = $sound.prop("checked");
    const hasWarning = $warning.prop("checked");

    this.soundUpdateInProgress = true;
    try {
      this.query = this.query.withSound(noSound, hasSound, hasWarning);
    } finally {
      this.soundUpdateInProgress = false;
    }
    this.syncSoundControls(this.query.sound);
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
