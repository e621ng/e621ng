const PostFlags = {};

PostFlags.init = function () {
  $(".post-flag-note").on("click", (event) => {
    $(event.currentTarget).toggleClass("expanded");
  });
};

export default PostFlags;

$(() => {
  PostFlags.init();
});
