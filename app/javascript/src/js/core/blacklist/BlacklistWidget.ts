import E621Type from "@/interfaces/E621";
import LStorage from "@/utility/storage/Local";

declare const E621: E621Type;

/**
 * Represents the list of toggles for the blacklist filters.
 * Could be either in a sidebar or inline formats.
 */
export default class BlacklistWidget {

  /* ============================== */
  /* === Static Manager Methods === */
  /* ============================== */

  private static registry: BlacklistWidget[] = [];

  public static initializeAll () {
    document.querySelectorAll("section.blacklist-ui.staged").forEach((element) => {
      this.registry.push(new BlacklistWidget(element as HTMLDivElement));
    });

    $(document).off("e621:blacklist:state-changed")
      .on("e621:blacklist:state-changed", () => {
        for (const widget of this.registry)
          widget.rebuildFilters();
      });
  }

  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private $wrapper: JQuery<HTMLDivElement>;
  private $counter: JQuery<HTMLSpanElement>;
  private $toggle: JQuery<HTMLButtonElement>;
  private $container: JQuery<HTMLUListElement>;

  private post: number;
  private hasPost: boolean;

  /**
   * Constructor.
   * Should only be run on `.blacklist-ui` elements.
   * @param {HTMLDivElement} wrapper
   */
  constructor (wrapper: HTMLDivElement) {
    this.$wrapper = $(wrapper).removeClass("staged");
    this.$counter = this.$wrapper.find("span.blacklisted-count");

    this.post = parseInt(this.$wrapper.attr("post") || "");
    this.hasPost = !Number.isNaN(this.post);

    // Collapsable header
    this.$wrapper
      .attr("collapsed", LStorage.Blacklist.Collapsed + "")
      .find(".blacklist-header")
      .off("click.blacklistWidget")
      .on("click.blacklistWidget", () => {
        const newState = this.$wrapper.attr("collapsed") !== "true";
        this.$wrapper.attr("collapsed", newState + "");
        LStorage.Blacklist.Collapsed = newState;
      });

    // Toggle All switch
    this.$toggle = this.$wrapper.find("button.blacklist-toggle-all");
    this.$toggle
      .text("Disable All Filters")
      .off("click.blacklistWidget")
      .on("click.blacklistWidget", () => {
        if (this.$toggle.attr("is-enabling") == "true") {
          for (const filter of Object.values(E621.Blacklist.filters))
            filter.setEnabledWithoutSaving(true);
          LStorage.Blacklist.FilterState.clear();
        } else {
          const filterList = new Set<string>();
          for (const filter of Object.values(E621.Blacklist.filters)) {
            filter.setEnabledWithoutSaving(false);
            filterList.add(filter.text);
          }
          LStorage.Blacklist.FilterState = filterList;
        }

        $(document).trigger("e621:blacklist:state-changed");
        E621.Blacklist.updatePostVisibility();
      });

    // Filters
    this.$container = this.$wrapper.find(".blacklist-filters");
    this.rebuildFilters();
  }

  /* ============================== */
  /* ======= Class Methods ======== */
  /* ============================== */

  /**
   * Deletes and re-creates the filter list.
   * Done automatically every time a filter gets turned on or off,
   * so all instances are in sync no matter what.
   */
  private rebuildFilters () {
    this.$container.html("");

    let activeFilters = 0,
      inactiveFilters = 0;
    for (const [name, filter] of Object.entries(E621.Blacklist.filters)) {
      if (filter.matchIDs.size == 0) continue;

      // Special case for the posts/show page sidebar
      if (this.hasPost && !filter.matchIDs.has(this.post))
        continue;

      activeFilters++;
      if (!filter.enabled) inactiveFilters++;

      const entry = $("<li>")
        .attr("enabled", filter.enabled + "")
        .on("click", () => {
          // Actual toggling done elsewhere
          filter.enabled = !filter.enabled;
        })
        .appendTo(this.$container);

      const link = $("<a>")
        .attr("href", "/posts?tags=" + encodeURIComponent(name))
        .html(name
          .replace(/_/g, "&#8203;_") // Allow tags to linebreak on underscores
          .replace(/ -/, " &#8209;"), // Prevent linebreaking on negated tags
        )
        .on("click", (event) => {
          event.preventDefault();
          // Link is disabled, but could still be right-clicked
        })
        .appendTo(entry);

      $("<span>").text(filter.matchIDs.size).appendTo(link);
    }

    // Update the total blacklist size
    this.$wrapper.attr("filters", activeFilters);
    this.$counter.text("(" + E621.Blacklist.hiddenPosts.size + ")");

    // Change the toggle state accordingly
    const text = inactiveFilters ? "Enable All Filters" : "Disable All Filters";
    this.$toggle
      .text(text)
      .attr({
        "is-enabling": inactiveFilters > 0,
        "aria-label": text,
      });
  }
}
