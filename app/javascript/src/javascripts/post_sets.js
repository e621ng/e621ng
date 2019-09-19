import {SendQueue} from './send_queue'
import Post from './posts.js.erb'

let PostSet = {};

PostSet.add_post = function (set_id, post_id) {
  Post.notice_update("inc");
  SendQueue.add(function () {
    $.ajax({
      type: "POST",
      url: "/post_sets/" + set_id + "/add_posts.json",
      data: {post_ids: [post_id]},
    }).fail(function (data) {
      var message = $.map(data.responseJSON.errors, function(msg, attr) { return msg; }).join('; ');
      $(window).trigger('danbooru:error', "Error: " + message);
    }).done(function () {
      $(window).trigger("danbooru:notice", "Added post to set");
    }).always(function () {
      Post.notice_update("dec");
    });
  });
};

PostSet.remove_post = function (set_id, post_id) {
  Post.notice_update("inc");
  SendQueue.add(function () {
    $.ajax({
      type: "POST",
      url: "/post_sets/" + set_id + "/remove_posts.json",
      data: {post_ids: [post_id]},
    }).fail(function (data) {
      var message = $.map(data.responseJSON.errors, function(msg, attr) { return msg; }).join('; ');
      $(window).trigger('danbooru:error', "Error: " + message);
    }).done(function () {
      $(window).trigger("danbooru:notice", "Removed post from set");
    }).always(function () {
      Post.notice_update("dec");
    });
  });
};

export default PostSet;
