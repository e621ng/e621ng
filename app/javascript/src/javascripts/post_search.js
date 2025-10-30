import LStorage from "./utility/storage";
import Page from "./utility/page";
import Offclick from "./utility/offclick";

const PostSearch = {};

PostSearch.initialize_input = function ($form) {
  const $textarea = $form.find("textarea[name='tags']").first();
  if (!$textarea.length) return;
  const element = $textarea[0];

  // Adjust the number of rows based on input length
  $textarea
    .on("input", recalculateInputHeight)
    .on("keypress", function (event) {
      if (event.which !== 13 || event.shiftKey) return;
      event.preventDefault();
      $textarea.closest("form").trigger("submit");
    });

  $(window).on("resize", recalculateInputHeight);

  // Reset default height
  recalculateInputHeight();

  function recalculateInputHeight () {
    $textarea.css("height", 0);
    $textarea.css("height", element.scrollHeight + "px");
  }
};

PostSearch.initialize_wiki_preview = function ($preview) {
  let visible = LStorage.Posts.WikiExcerpt;
  if (visible == 2) return; // hidden
  if (visible == 1) $preview.addClass("open");
  $preview.removeClass("hidden");

  window.setTimeout(() => { // Disable the rollout on first load
    $preview.removeClass("loading");
  }, 250);

  // Toggle the excerpt box open / closed
  $($preview.find("h3.wiki-excerpt-toggle")).on("click", (event) => {
    event.preventDefault();

    visible = !visible;
    $preview.toggleClass("open", visible);
    LStorage.Posts.WikiExcerpt = Number(visible);

    return false;
  });

  // Hide the excerpt box entirely
  $preview.find("button.wiki-excerpt-dismiss").on("click", (event) => {
    event.preventDefault();

    $preview.addClass("hidden");
    LStorage.Posts.WikiExcerpt = 2;

    return false;
  });
};

PostSearch.initialize_controls = function () {
  // Regular buttons
  let fullscreen = LStorage.Posts.Fullscreen;
  $("#search-fullscreen").on("click", () => {
    fullscreen = !fullscreen;
    $("body").attr("data-st-fullscreen", fullscreen);
    LStorage.Posts.Fullscreen = fullscreen;
  });

  // Menu open / close
  const offclickHandler = Offclick.register("#search-settings", ".search-settings-container", () => {
    menu.removeClass("active");
    menuButton.removeClass("active");
  });

  const menu = $(".search-settings-container");
  const menuButton = $("#search-settings").on("click", () => {
    const state = offclickHandler.disabled;
    menu.toggleClass("active", state);
    menuButton.toggleClass("active", state);
    offclickHandler.disabled = !state;
  });

  $("#search-settings-close").on("click", (event) => {
    event.preventDefault();
    menu.removeClass("active");
    menuButton.removeClass("active");
    offclickHandler.disabled = true;
  });

  // Menu toggles
  $("#ssc-image-contain")
    .prop("checked", LStorage.Posts.Contain)
    .on("change", (event) => {
      LStorage.Posts.Contain = event.target.checked;
      $("body").attr("data-st-contain", event.target.checked);
    });

  $("input[type='radio'][name='ssc-card-size']")
    .on("change", (event) => {
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
    .on("change", (event) => {
      LStorage.Posts.HoverText = event.target.value;
      updateHoverTextNodes();
    });
  $("input[type='radio'][name='ssc-hover-text'][value='" + LStorage.Posts.HoverText + "']")
    .prop("checked", true);
  updateHoverTextNodes();

  $("#ssc-sticky-searchbar")
    .prop("checked", LStorage.Posts.StickySearch)
    .on("change", (event) => {
      LStorage.Posts.StickySearch = event.target.checked;
      $("body").attr("data-st-stickysearch", event.target.checked);
    });
};

$(() => {

  $(".post-search").each((index, element) => {
    PostSearch.initialize_input($(element));
  });

  if (!Page.matches("posts") && !Page.matches("favorites"))
    return;

  $(".wiki-excerpt").each((index, element) => {
    PostSearch.initialize_wiki_preview($(element));
  });

  PostSearch.initialize_controls();
});

export default PostSearch;
