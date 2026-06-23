import Offclick, { OffclickEntry } from "../../utility/Offclick";
import LStorage from "../../utility/storage/Local";

export default class SearchControls {

  private advOffclickHandler: OffclickEntry;
  private layoutOffclickHandler: OffclickEntry;

  constructor () {
    this.initFullscreenToggle();
    this.initAdvancedSearch();
    this.initLayoutSettings();
  }

  private initFullscreenToggle () {
    let fullscreen = LStorage.Posts.Fullscreen;
    const $toggleBtn = $("#toggle-fullscreen");

    function setFullscreenIcon () {
      $toggleBtn.toggleClass("active", fullscreen);
      $("body").attr("data-st-fullscreen", fullscreen + "");
    }

    setFullscreenIcon();
    $toggleBtn.on("click", () => {
      fullscreen = !fullscreen;
      LStorage.Posts.Fullscreen = fullscreen;
      setFullscreenIcon();
    });
  }

  private initAdvancedSearch () {
    const advSearch = $("#advanced-search-container"),
      advSearchBtn = $("#advanced-search-open");

    this.advOffclickHandler = Offclick.register(
      "#advanced-search-open",
      "#advanced-search-container, .search",
      () => {
        advSearch.removeClass("active");
        advSearchBtn.removeClass("active");
      },
    );

    advSearchBtn.on("click", () => {
      const state = this.advOffclickHandler.disabled;
      advSearch.toggleClass("active", state);
      advSearchBtn.toggleClass("active", state);
      this.advOffclickHandler.disabled = !state;

      if (state) this.layoutOffclickHandler.trigger(); // Close layout settings
    });

    advSearch.find("#advanced-search-close").on("click", (event) => {
      event.preventDefault();
      this.advOffclickHandler.trigger();
    });
  }

  private initLayoutSettings () {
    const menu = $("#layout-settings-container"),
      menuButton = $("#layout-settings-open");

    this.layoutOffclickHandler = Offclick.register(
      "#layout-settings-open",
      "#layout-settings-container",
      () => {
        menu.removeClass("active");
        menuButton.removeClass("active");
      },
    );

    menuButton.on("click", () => {
      const state = this.layoutOffclickHandler.disabled;
      menu.toggleClass("active", state);
      menuButton.toggleClass("active", state);
      this.layoutOffclickHandler.disabled = !state;

      if (state) this.advOffclickHandler.trigger(); // Close advanced search
    });

    $("#layout-settings-close").on("click", (event) => {
      event.preventDefault();
      this.layoutOffclickHandler.trigger();
    });

    // Menu toggles
    $("#ssc-image-contain")
      .prop("checked", LStorage.Posts.Contain)
      .on("change", (event: JQuery.ChangeEvent<HTMLInputElement>) => {
        LStorage.Posts.Contain = event.target.checked;
        $("body").attr("data-st-contain", event.target.checked);
      });

    $("input[type='radio'][name='ssc-card-size']")
      .on("change", (event: JQuery.ChangeEvent<HTMLInputElement>) => {
        LStorage.Posts.Size = event.target.value;
        $("body").attr("data-st-size", event.target.value);
      });
    $("input[type='radio'][name='ssc-card-size'][value='" + LStorage.Posts.Size + "']")
      .prop("checked", true);

    function updateHoverTextNodes () {
      $("a[data-hover-text]").attr("title", function () {
        const source = $(this).data("hover-text");
        if (!source) return "";

        switch (LStorage.Posts.HoverText) {
          case "none":
            return "";
          case "short":
            return source.split("\n\n")[0];
          case "long":
          default:
            return source;
        }
      });
    }
    $("input[type='radio'][name='ssc-hover-text']")
      .on("change", (event: JQuery.ChangeEvent<HTMLInputElement>) => {
        LStorage.Posts.HoverText = event.target.value;
        updateHoverTextNodes();
      });
    $("input[type='radio'][name='ssc-hover-text'][value='" + LStorage.Posts.HoverText + "']")
      .prop("checked", true);
    updateHoverTextNodes();

    $("#ssc-corner-ribbons")
      .prop("checked", LStorage.Posts.CornerRibbons)
      .on("change", (event: JQuery.ChangeEvent<HTMLInputElement>) => {
        LStorage.Posts.CornerRibbons = event.target.checked;
        $("body").attr("data-st-cornerribbons", event.target.checked);
      });

    $("#ssc-sticky-searchbar")
      .prop("checked", LStorage.Posts.StickySearch)
      .on("change", (event: JQuery.ChangeEvent<HTMLInputElement>) => {
        LStorage.Posts.StickySearch = event.target.checked;
        $("body").attr("data-st-stickysearch", event.target.checked);
      });
  }
}

$(() => {
  new SearchControls();
});
