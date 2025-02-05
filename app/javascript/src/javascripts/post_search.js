import LStorage from "./utility/storage";
import Page from "./utility/page";

const PostSearch = {};

PostSearch.init = function () {
  $(".post-search").each((index, element) => {
    PostSearch.initialize_input($(element));
  });

  $(".wiki-excerpt").each((index, element) => {
    PostSearch.initialize_wiki_preview($(element));
  });

  PostSearch.initialize_controls();
};

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
      $textarea.closest("form").submit();
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
  if (visible) $preview.addClass("open");
  window.setTimeout(() => { // Disable the rollout on first load
    $preview.removeClass("loading");
  }, 250);

  $($preview.find("h3.wiki-excerpt-toggle")).on("click", (event) => {
    event.preventDefault();

    visible = !visible;
    $preview.toggleClass("open", visible);
    LStorage.Posts.WikiExcerpt = visible;

    return false;
  });
};

PostSearch.initialize_controls = function () {
  let fullscreen = LStorage.Posts.Fullscreen;
  $("#search-fullscreen").on("click", () => {
    fullscreen = !fullscreen;
    $("body").attr("data-st-fullscreen", fullscreen);
    LStorage.Posts.Fullscreen = fullscreen;
  });
};

$(() => {
  if (!Page.matches("posts", "index") && !Page.matches("favorites"))
    return;

  PostSearch.init();
});

export default PostSearch;
