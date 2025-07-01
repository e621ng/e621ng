import LStorage from "./utility/storage";
import Page from "./utility/page";

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

  // Menu toggle
  let settingsVisible = false;
  const menu = $(".search-settings-container"),
    menuButton = $("#search-settings");
  menuButton.on("click", () => {
    settingsVisible = !settingsVisible;
    menu.toggleClass("active", settingsVisible);
    menuButton.toggleClass("active", settingsVisible);
  });

  $("#search-settings-close").on("click", (event) => {
    event.preventDefault();
    menu.removeClass("active");
    menuButton.removeClass("active");
    settingsVisible = false;
  });

  // click outside the menu
  $(window).on("mouseup", (event) => {
    if (!settingsVisible) return;

    const target = $(event.target);
    if (target.closest(".search-settings-container").length > 0 || target.is("#search-settings"))
      return;

    menu.removeClass("active");
    menuButton.removeClass("active");
    settingsVisible = false;
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
