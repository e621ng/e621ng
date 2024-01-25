import Post from './posts'
import Utility from './utility'
import {SendQueue} from './send_queue'

let Favorite = {};

Favorite.initialize_actions = function () {
  $("#add-to-favorites, #add-fav-button").on("click", e => {
    e.preventDefault();
    Favorite.create($(e.target).closest(".button").data("pid"));
  });
  $("#remove-from-favorites, #remove-fav-button").on("click", e => {
    e.preventDefault();
    Favorite.destroy($(e.target).closest(".button").data("pid"));
  });
};

Favorite.after_action = function (post_id, offset) {
  $("#add-to-favorites, #add-fav-button, #remove-from-favorites, #remove-fav-button").toggle();
  $("#remove-fav-button").addClass("animate");
  setTimeout(function () {
    $("#remove-fav-button").removeClass("animate");
  }, 3000);
  const count = $(`#favcount-for-post-${post_id}`);
  const count_number = parseInt(count.text(), 10);
  count.text(count_number + offset);
  $(".fav-buttons").toggleClass("fav-buttons-false").toggleClass("fav-buttons-true");
};

Favorite.create = function (post_id) {
  Post.notice_update("inc");

  SendQueue.add(function () {
    $.ajax({
      type: "POST",
      url: "/favorites.json",
      data: {
        post_id: post_id
      },
      dataType: 'json'
    }).done(function () {
      Post.notice_update("dec");
      Favorite.after_action(post_id, 1);
      Utility.notice("Favorite added");
    }).fail(function (data, status, xhr) {
      Utility.error("Error: " + data.responseJSON.message);
    });
  });
};

Favorite.destroy = function (post_id) {
  Post.notice_update("inc");

  SendQueue.add(function () {
    $.ajax({
      type: "DELETE",
      url: "/favorites/" + post_id + ".json",
      dataType: 'json'
    }).done(function () {
      Post.notice_update("dec");
      Favorite.after_action(post_id, -1);
      Utility.notice("Favorite removed");
    }).fail(function (data, status, xhr) {
      Utility.error("Error: " + data.responseJSON.message);
    });
  });
};

$(Favorite.initialize_actions);

export default Favorite
