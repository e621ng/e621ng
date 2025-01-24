const PostSearch = {};

PostSearch.init = function () {
  $(".post-search").each((index, element) => {
    PostSearch.initialize_input($(element));
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

$(() => {
  PostSearch.init();
});

export default PostSearch;
