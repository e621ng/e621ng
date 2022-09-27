import Blip from './blips.js';
import Comment from './comments.js';
import DText from './dtext.js';
import ForumPost from './forum_posts.js';
import Utility from './utility.js';

class UserWarnable {
  static initialize_click_handlers() {
    $('.item-mark-user-warned').on('click', evt => {
      evt.preventDefault();
      const target = $(evt.target);
      const type = target.data('item-route');
      const id = target.data('item-id');
      const record_type = target.data('record-type');

      $.ajax({
        type: "POST",
        url: `/${type}/${id}/warning.json`,
        data: {
          'record_type': record_type
        },
      }).done(data => {
        target.closest("article.blip, article.comment, article.forum-post").replaceWith(data.html);
        $(window).trigger("e621:add_deferred_posts", data.posts);

        this.reinitialize_click_handlers();
        Blip.reinitialize_all();
        Comment.reinitialize_all();
        ForumPost.reinitialize_all();
        DText.initialize_all_inputs();
      }).fail(data => {
        Utility.error("Failed to mark as warned.");
      });
    });
  }

  static reinitialize_click_handlers() {
    $(".item-mark-user-warned").off("click");
    this.initialize_click_handlers();
  }
}

$(() => {
  UserWarnable.initialize_click_handlers();
});
