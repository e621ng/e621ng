import {SendQueue} from './send_queue'
import Post from './posts'
import LS from './local_storage'

let PostSet = {};

PostSet.dialog_setup = false;

PostSet.add_post = function (set_id, post_id) {
  Post.notice_update("inc");
  SendQueue.add(function () {
    $.ajax({
      type: "POST",
      url: "/post_sets/" + set_id + "/add_posts.json",
      data: {post_ids: [post_id]},
    }).fail(function (data) {
      var message = $.map(data.responseJSON.errors, function(msg, attr) { return msg; }).join('; ');
      Post.notice_update("dec");
      $(window).trigger('danbooru:error', "Error: " + message);
    }).done(function () {
      Post.notice_update("dec");
      $(window).trigger("danbooru:notice", "Added post to set");
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
      Post.notice_update("dec");
      $(window).trigger('danbooru:error', "Error: " + message);
    }).done(function () {
      Post.notice_update("dec");
      $(window).trigger("danbooru:notice", "Removed post from set");
    });
  });
};

PostSet.initialize_add_to_set_link = function() {
  $("#set").on("click.danbooru", function(e) {
    if (!PostSet.dialog_setup) {
      $("#add-to-set-dialog").dialog({autoOpen: false});
      PostSet.dialog_setup = true;
    }
    e.preventDefault();
    PostSet.update_sets_menu();
    $("#add-to-set-dialog").dialog("open");
  });

  $("#add-to-set-submit").on("click", function(e) {
    e.preventDefault();
    const post_id = $('#image-container').data('id');
    PostSet.add_post($("#add-to-set-id").val(), post_id);
    $('#add-to-set-dialog').dialog('close');
  });
};

PostSet.update_sets_menu = function() {
  const target = $('#add-to-set-id');
  target.empty();
  target.append($('<option>').text('Loading...'));
  target.off('change');
  SendQueue.add(function() {
    $.ajax({
      type: "GET",
      url: "/post_sets/for_select.json",
    }).fail(function(data) {
      $(window).trigger('danbooru:error', "Error getting sets list: " + data.message);
    }).done(function(data) {
      target.on('change', function(e) {
        LS.put('set', e.target.value);
      })
      const target_set = LS.get('set') || 0;
      target.empty();
      ['Owned', "Maintained"].forEach(function(v) {
        let group = $('<optgroup>', {label: v});
        data[v].forEach(function(gi) {
          group.append($('<option>', {value: gi[1], selected: (gi[1] == target_set)}).text(gi[0]));
        });
        target.append(group);
      });
    });
  });
};

$(function() {
  if ($("#c-posts").length && $('#a-show').length) {
    PostSet.initialize_add_to_set_link();
  }
});

export default PostSet;
