import Blip from "./blips.js";
import Comment from "./comments.js";
import ForumPost from "./forum_posts.js";
import Utility from "./utility.js";

class UserWarnable {
  static initialize_click_handlers () {
    $(".item-mark-user-warned").on("click", evt => {
      evt.preventDefault();
      const target = $(evt.target);
      const type = target.data("item-route");
      const id = target.data("item-id");
      const item_type = target.data("item-type");
      const record_type = target.data("record-type");

      const message = record_type === "unmark"
        ? `Are you sure you want to unmark this ${item_type}?`
        : `Are you sure you want to mark this ${item_type} for having received ${record_type}?`;
      if (!confirm(message)) {
        return;
      }

      $.ajax({
        type: "POST",
        url: `/${type}/${id}/warning.json`,
        data: {
          "record_type": record_type,
        },
      }).done(data => {
        target.closest("article.blip, article.comment, article.forum-post").replaceWith(data.html);
        $(window).trigger("e621:add_deferred_posts", data.posts);

        this.reinitialize_click_handlers();
        Blip.reinitialize_all();
        Comment.reinitialize_all();
        ForumPost.reinitialize_all();
      }).fail(() => {
        Utility.error("Failed to mark as warned.");
      });
    });
  }

  static reinitialize_click_handlers () {
    $(".item-mark-user-warned").off("click");
    this.initialize_click_handlers();
  }
}

$(() => {
  UserWarnable.initialize_click_handlers();
});
