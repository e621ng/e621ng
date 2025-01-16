let ForumTopic = {};

ForumTopic.init_mark_all_as_read = function () {
  $("#subnav-mark-all-as-read-link").on("click.danbooru", () => {
    return confirm(`Are you sure that you want to mark all ${$("body").data("controller").replace(/-/g, " ")} as read?`);
  });
};

$(() => {
  ForumTopic.init_mark_all_as_read();
});

export default ForumTopic;
