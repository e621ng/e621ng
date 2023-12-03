import Utility from './utility'
import LS from './local_storage'
import Post from './posts'
import Favorite from './favorites'
import PostSet from './post_sets'
import TagScript from './tag_script'
import { SendQueue } from './send_queue'
import Rails from '@rails/ujs'
import Shortcuts from './shortcuts'

let PostModeMenu = {};

PostModeMenu.initialize = function() {
  if ($("#c-posts").length || $("#c-favorites").length || $("#c-pools").length) {
    this.initialize_selector();
    this.initialize_preview_link();
    this.initialize_edit_form();
    this.initialize_tag_script_field();
    this.initialize_shortcuts();
    PostModeMenu.change();
  }
}

PostModeMenu.initialize_shortcuts = function() {
  Shortcuts.keydown("1 2 3 4 5 6 7 8 9 0", "change_tag_script", PostModeMenu.change_tag_script);
}

PostModeMenu.show_notice = function(i) {
  Utility.notice("Switched to tag script #" + i + ". To switch tag scripts, use the number keys.");
}

PostModeMenu.change_tag_script = function(e) {
  if ($("#mode-box-mode").val() === "tag-script") {
    const old_tag_script_id = LS.get("current_tag_script_id") || "1";

    const new_tag_script_id = parseInt(e.key, 10);
    const new_tag_script = LS.get("tag-script-" + new_tag_script_id);

    $("#tag-script-field").val(new_tag_script);
    LS.put("current_tag_script_id", new_tag_script_id);
    if (old_tag_script_id !== new_tag_script_id) {
      PostModeMenu.show_notice(new_tag_script_id);
    }

    e.preventDefault();
  }
}

PostModeMenu.initialize_selector = function() {
  if (!LS.get("mode")) {
    LS.put("mode", "view");
    $("#mode-box-mode").val("view");
  } else {
    $("#mode-box-mode").val(LS.get("mode"));
  }

  $("#mode-box-mode").on("change.danbooru", function(e) {
    PostModeMenu.change();
    $("#tag-script-field:visible").focus().select();
  });
}

PostModeMenu.initialize_preview_link = function() {
  $(".post-preview a").on("click.danbooru", PostModeMenu.click);
}

PostModeMenu.initialize_edit_form = function() {
  $("#quick-edit-div").hide();
  $("#quick-edit-form input[value=Cancel]").on("click.danbooru", function(e) {
    PostModeMenu.close_edit_form();
    e.preventDefault();
  });

  $("#quick-edit-form").on("submit.danbooru", function(e) {
    $.ajax({
      type: "put",
      url: $("#quick-edit-form").attr("action"),
      data: {
        post: {
          tag_string: $("#post_tag_string").val()
        }
      },
      complete: function() {
        Rails.enableElement(document.getElementById("quick-edit-form"));
      },
      success: function(data) {
        Post.update_data(data);
        Utility.notice("Post #" + data.post.id + " updated");
        PostModeMenu.close_edit_form();
      }
    });

    e.preventDefault();
  });
}

PostModeMenu.close_edit_form = function() {
  Shortcuts.disabled = false;
  $("#quick-edit-div").slideUp("fast");
  if (Utility.meta("enable-auto-complete") === "true") {
    $("#post_tag_string").data("uiAutocomplete").close();
  }
}

PostModeMenu.initialize_tag_script_field = function() {
  $("#tag-script-field").blur(function(e) {
    const script = $(this).val();

    const current_script_id = LS.get("current_tag_script_id");
    LS.put("tag-script-" + current_script_id, script);
  });
}

PostModeMenu.update_sets_menu = function() {
  let target = $('#set-id');
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
      });
      target.empty();
      const target_set = LS.get('set') || 0;
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

PostModeMenu.change = function() {
  $("#quick-edit-div").slideUp("fast");
  const s = $("#mode-box-mode").val();
  if (s === undefined) {
    return;
  }
  $("#page").attr("data-mode-menu", s);
  LS.put("mode", s, 1);
  $("#set-id").hide();
  $("#tag-script-field").hide();
  $("#quick-mode-reason").hide();

  if (s === "tag-script") {
    let current_script_id = LS.get("current_tag_script_id");
    if (!current_script_id) {
      current_script_id = "1";
      LS.put("current_tag_script_id", current_script_id);
    }
    const script = LS.get("tag-script-" + current_script_id);

    $("#tag-script-field").val(script).show();
    PostModeMenu.show_notice(current_script_id);
  } else if (s === 'add-to-set' || s === 'remove-from-set') {
    PostModeMenu.update_sets_menu();
    $("#set-id").show();
  } else if (s === 'delete') {
    $("#quick-mode-reason").show();
  }
}

PostModeMenu.open_edit = function(post_id) {
  Shortcuts.disabled = true;
  var $post = $("#post_" + post_id);
  $("#quick-edit-div").slideDown("fast");
  $("#quick-edit-form").attr("action", "/posts/" + post_id + ".json");
  $("#post_tag_string").val($post.data("tags") + " ").focus().selectEnd();

  /* Set height of tag edit box to fit content. */
  $("#post_tag_string").height(80); // min height: 80px.
  var padding = $("#post_tag_string").innerHeight() - $("#post_tag_string").height();
  var height = $("#post_tag_string").prop("scrollHeight") - padding;
  $("#post_tag_string").height(height);
}

PostModeMenu.click = function(e) {
  var s = $("#mode-box-mode").val();
  var post_id = $(e.target).closest("article").data("id");

  if (s === "add-fav") {
    Favorite.create(post_id);
  } else if (s === "remove-fav") {
    Favorite.destroy(post_id);
  } else if (s === "edit") {
    PostModeMenu.open_edit(post_id);
  } else if (s === 'vote-down') {
    Post.vote(post_id, -1, true);
  } else if (s === 'vote-up') {
    Post.vote(post_id, 1, true);
  } else if (s === 'add-to-set') {
    PostSet.add_post($("#set-id").val(), post_id);
  } else if (s === 'remove-from-set') {
    PostSet.remove_post($("#set-id").val(), post_id);
  } else if (s === 'rating-q') {
    Post.update(post_id, {"post[rating]": "q"})
  } else if (s === 'rating-s') {
    Post.update(post_id, {"post[rating]": "s"})
  } else if (s === 'rating-e') {
    Post.update(post_id, {"post[rating]": "e"})
  } else if (s === 'lock-rating') {
    Post.update(post_id, {"post[is_rating_locked]": "1"});
  } else if (s === 'lock-note') {
    Post.update(post_id, {"post[is_note_locked]": "1"});
  } else if (s === 'delete') {
    Post.delete_with_reason(post_id, $("#quick-mode-reason").val(), false);
  } else if (s === 'undelete') {
    Post.undelete(post_id);
  } else if (s === 'unflag') {
    Post.unflag(post_id, "none", false);
  } else if (s === 'approve') {
    Post.approve(post_id);
  } else if (s === 'remove-parent') {
    Post.update(post_id, {"post[parent_id]": ""});
  } else if (s === "tag-script") {
    const current_script_id = LS.get("current_tag_script_id");
    const tag_script = LS.get("tag-script-" + current_script_id);
    if (!tag_script) {
      e.preventDefault();
      return;
    }
    const postTags = $("#post_" + post_id).data('tags').split(' ');
    const tags = new Set(postTags);
    const changes = TagScript.run(tags, tag_script);
    Post.tagScript(post_id, changes);
  } else {
    return;
  }

  e.preventDefault();
}

$(function() {
  PostModeMenu.initialize();
});

export default PostModeMenu
