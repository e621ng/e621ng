let ForumTopic = {};

// For reasons unknown to me, someone decided to have this code control both the "mark as read"
// buttons for both forum topics and DMails. Those are not even related, why are we doing this?

ForumTopic.init_mark_all_as_read = function () {
  $("#subnav-mark-all-as-read-link").on("click.danbooru", () => {
    return confirm(`Are you sure that you want to mark all ${$("body").data("controller").replace(/-/g, " ")} as read?`);
  });
};

$(() => {
  ForumTopic.init_mark_all_as_read();
});

export default ForumTopic;
