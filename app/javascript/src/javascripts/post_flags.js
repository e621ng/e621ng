const PostFlags = {};

PostFlags.init = function () {
  for (const container of $(".post-flag-note")) {
    if (container.clientHeight > 72) $(container).addClass("expandable");
  }

  $(".post-flag-note-header").on("click", (event) => {
    $(event.currentTarget).parents(".post-flag-note").toggleClass("expanded");
  });
};

export default PostFlags;

$(() => {
  PostFlags.init();
});
