import Utility from "./utility";
import Post from "./posts";
import Favorite from "./favorites";
import PostSet from "./post_sets";
import TagScript from "./tag_script";
import { SendQueue } from "./send_queue";
import Rails from "@rails/ujs";
import Shortcuts from "./shortcuts";
import LStorage from "./utility/storage";

let PostModeMenu = {};

PostModeMenu.initialize = function () {
  if ($("#c-posts").length || $("#c-favorites").length || $("#c-pools").length) {
    this.initialize_selector();
    this.initialize_preview_link();
    this.initialize_edit_form();
    this.initialize_tag_script_field();
    this.initialize_shortcuts();
    PostModeMenu.change();
  }
};

PostModeMenu.initialize_shortcuts = function () {
  Shortcuts.keydown("1 2 3 4 5 6 7 8 9 0", "change_tag_script", PostModeMenu.change_tag_script);
};

PostModeMenu.show_notice = function (i) {
  Utility.notice("Switched to tag script #" + i + ". To switch tag scripts, use the number keys.");
};

PostModeMenu.change_tag_script = function (e) {
  if ($("#mode-box-mode").val() !== "tag-script")
    return;
  e.preventDefault();

  const newScriptID = Number(e.key);
  console.log(newScriptID, LStorage.Posts.TagScript.ID);
  if (!newScriptID || newScriptID == LStorage.Posts.TagScript.ID)
    return;

  LStorage.Posts.TagScript.ID = newScriptID;
  console.log("settings", LStorage.Posts.TagScript.ID, LStorage.Posts.TagScript.Content);
  $("#tag-script-field").val(LStorage.Posts.TagScript.Content);
  PostModeMenu.show_notice(newScriptID);
};

PostModeMenu.initialize_selector = function () {
  $("#mode-box-mode").val(LStorage.Posts.Mode);

  $("#mode-box-mode").on("change.danbooru", function () {
    PostModeMenu.change();
    $("#tag-script-field:visible").focus().select();
  });
};

PostModeMenu.initialize_preview_link = function () {
  $(".thumbnail").on("click.danbooru", PostModeMenu.click);
};

PostModeMenu.initialize_edit_form = function () {
  $("#quick-edit-div").hide();
  $("#quick-edit-form input[value=Cancel]").on("click.danbooru", function (e) {
    PostModeMenu.close_edit_form();
    e.preventDefault();
  });

  $("#quick-edit-form").on("submit.danbooru", function (e) {
    $.ajax({
      type: "put",
      url: $("#quick-edit-form").attr("action"),
      data: {
        post: {
          tag_string: $("#post_tag_string").val(),
        },
      },
      complete: function () {
        Rails.enableElement(document.getElementById("quick-edit-form"));
      },
      success: function (data) {
        Post.update_data(data);
        Utility.notice("Post #" + data.post.id + " updated");
        PostModeMenu.close_edit_form();
      },
    });

    e.preventDefault();
  });
};

PostModeMenu.close_edit_form = function () {
  Shortcuts.disabled = false;
  $("#quick-edit-div").slideUp("fast");
  if (Utility.meta("enable-auto-complete") === "true") {
    $("#post_tag_string").data("uiAutocomplete").close();
  }
};

PostModeMenu.initialize_tag_script_field = function () {
  $("#tag-script-field").on("blur", function () {
    const script = $(this).val();
    LStorage.Posts.TagScript.Content = script;
  });

  $("#tag-script-all").on("click", PostModeMenu.tag_script_apply_all);
};

PostModeMenu.tag_script_apply_all = function (event) {
  event.preventDefault();
  const posts = $("article.thumbnail");
  if (!confirm(`Apply the tag script to ${posts.length} posts?`)) return;
  posts.trigger("click");
};

PostModeMenu.update_sets_menu = function () {
  let target = $("#set-id");
  target.off("change");
  SendQueue.add(function () {
    $.ajax({
      type: "GET",
      url: "/post_sets/for_select.json",
    }).fail(function (data) {
      $(window).trigger("danbooru:error", "Error getting sets list: " + data.message);
    }).done(function (data) {
      target.on("change", function (e) {
        LStorage.Posts.Set = e.target.value;
      });
      target.empty();
      const target_set = LStorage.Posts.Set;
      ["Owned", "Maintained"].forEach(function (v) {
        let group = $("<optgroup>", {label: v});
        data[v].forEach(function (gi) {
          group.append($("<option>", {value: gi[1], selected: (gi[1] == target_set)}).text(gi[0]));
        });
        target.append(group);
      });
    });
  });
};

PostModeMenu.change = function () {
  $("#quick-edit-div").slideUp("fast");
  const s = $("#mode-box-mode").val();
  if (s === undefined) {
    return;
  }
  $("#page").attr("data-mode-menu", s);
  LStorage.Posts.Mode = s;
  $("#set-id").hide();
  $("#tag-script-ui").hide();
  $("#quick-mode-reason").hide();

  if (s === "tag-script") {
    $("#tag-script-ui").show();
    $("#tag-script-field").val(LStorage.Posts.TagScript.Content).show();
    PostModeMenu.show_notice(LStorage.Posts.TagScript.ID);
  } else if (s === "add-to-set" || s === "remove-from-set") {
    PostModeMenu.update_sets_menu();
    $("#set-id").show();
  } else if (s === "delete") {
    $("#quick-mode-reason").show();
  }
};

PostModeMenu.open_edit = function (post_id) {
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
};

PostModeMenu.click = function (e) {
  var s = $("#mode-box-mode").val();
  var post_id = $(e.currentTarget).data("id");

  if (s === "add-fav") {
    Favorite.create(post_id);
  } else if (s === "remove-fav") {
    Favorite.destroy(post_id);
  } else if (s === "edit") {
    PostModeMenu.open_edit(post_id);
  } else if (s === "vote-down") {
    Post.vote(post_id, -1, true);
  } else if (s === "vote-up") {
    Post.vote(post_id, 1, true);
  } else if (s === "add-to-set") {
    PostSet.add_post($("#set-id").val(), post_id);
  } else if (s === "remove-from-set") {
    PostSet.remove_post($("#set-id").val(), post_id);
  } else if (s === "rating-q") {
    Post.update(post_id, {"post[rating]": "q"});
  } else if (s === "rating-s") {
    Post.update(post_id, {"post[rating]": "s"});
  } else if (s === "rating-e") {
    Post.update(post_id, {"post[rating]": "e"});
  } else if (s === "lock-rating") {
    Post.update(post_id, {"post[is_rating_locked]": "1"});
  } else if (s === "lock-note") {
    Post.update(post_id, {"post[is_note_locked]": "1"});
  } else if (s === "delete") {
    Post.delete_with_reason(post_id, $("#quick-mode-reason").val(), false);
  } else if (s === "undelete") {
    Post.undelete(post_id);
  } else if (s === "unflag") {
    Post.unflag(post_id, "none", false);
  } else if (s === "approve") {
    Post.approve(post_id);
  } else if (s === "remove-parent") {
    Post.update(post_id, {"post[parent_id]": ""});
  } else if (s === "tag-script") {
    const tag_script = LStorage.Posts.TagScript.Content;
    if (!tag_script) {
      e.preventDefault();
      return;
    }
    const postTags = $("#post_" + post_id).data("tags").split(" ");
    const tags = new Set(postTags);
    const changes = TagScript.run(tags, tag_script);
    Post.tagScript(post_id, changes);
  } else {
    return;
  }

  e.preventDefault();
};

$(function () {
  PostModeMenu.initialize();
});

export default PostModeMenu;
