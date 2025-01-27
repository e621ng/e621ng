import LStorage from "./utility/storage";

const PostSearch = {};

PostSearch.init = function () {
  $(".post-search").each((index, element) => {
    PostSearch.initialize_input($(element));
  });

  $(".wiki-excerpt").each((index, element) => {
    PostSearch.initialize_wiki_preview($(element));
  });
};

PostSearch.initialize_input = function ($form) {
  const $textarea = $form.find("textarea[name='tags']").first();
  if (!$textarea.length) return;
  const element = $textarea[0];

  // Adjust the number of rows based on input length
  $textarea
    .on("input", () => {
      $textarea.css("height", 0);
      $textarea.css("height", element.scrollHeight + "px");
    })
    .on("keypress", function (event) {
      if (event.which !== 13 || event.shiftKey) return;
      event.preventDefault();
      $textarea.closest("form").submit();
    });

  // Reset default height
  $textarea.trigger("input");
};

PostSearch.initialize_wiki_preview = function ($preview) {
  let visible = LStorage.Posts.WikiExcerpt;
  if (visible)
    $preview.removeClass("hidden");
  console.log("init", visible);

  $($preview.find("a.wiki-excerpt-toggle")).on("click", (event) => {
    event.preventDefault();

    visible = !visible;
    $preview.toggleClass("hidden", !visible);
    LStorage.Posts.WikiExcerpt = visible;
    console.log("state", visible);

    return false;
  });
};

$(() => {
  PostSearch.init();
});

export default PostSearch;
