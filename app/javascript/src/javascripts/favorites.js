import Post from './posts.js.erb'
import Utility from './utility'
import {SendQueue} from './send_queue'

let Favorite = {};

Favorite.create = function (post_id) {
  Post.notice_update("inc");

  SendQueue.add(function () {
    $.ajax({
      type: "POST",
      url: "/favorites.js",
      data: {
        post_id: post_id
      },
      complete: function () {
        Post.notice_update("dec");
      },
      error: function (data, status, xhr) {
        Utility.notice("Error: " + data.reason);
      }
    });
  });
};

Favorite.destroy = function (post_id) {
  Post.notice_update("inc");

  SendQueue.add(function () {
    $.ajax({
      type: "DELETE",
      url: "/favorites/" + post_id + ".js",
      complete: function () {
        Post.notice_update("dec");
      }
    });
  });
};

export default Favorite

