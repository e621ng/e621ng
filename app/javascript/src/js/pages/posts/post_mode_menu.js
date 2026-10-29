import ToastManager from "@/utility/Toast";
import BulkActions from "@/pages/posts/BulkActions";
import PendingUpdates from "@/pages/posts/PendingUpdates";
import PostModel from "@/models/Post";
import Favorite from "@/models/Favorite";
import PostSet from "@/pages/posts/show/PostSet";
import TagScript, { TagScriptError } from "@/pages/posts/TagScript";
import PostCache from "@/models/PostCache";
import Rails from "@rails/ujs";
import Hotkeys from "@/core/hotkeys";
import LStorage from "@/utility/storage/Local";
import SStorage from "@/utility/storage/Session";
import PostVote from "@/models/PostVote";
import Autocomplete from "@/components/autocomplete";
import CurrentUser from "@/models/CurrentUser";

let PostModeMenu = {};

PostModeMenu.initialize = function () {
  if ($("#c-posts").length || $("#c-favorites").length || $("#c-pools").length) {
    this.initialize_selector();
    this.initialize_preview_link();
    this.initialize_edit_form();
    this.initialize_tag_script_field();
    if (CurrentUser.is.privileged) this.initialize_shortcuts();
    PostModeMenu.change();
  }
};

PostModeMenu.initialize_shortcuts = function () {
  for (let i = 1; i < 10; i++)
    Hotkeys.register(`tag-script-${i}`, () => PostModeMenu.change_tag_script(i));
};

PostModeMenu.show_notice_toast = null;
PostModeMenu.show_notice = function (i) {
  if (PostModeMenu.show_notice_toast) PostModeMenu.show_notice_toast.dismiss(true);
  PostModeMenu.show_notice_toast = ToastManager.create(`Switched to tag script #${i}. To switch tag scripts, use the number keys.`);
};

PostModeMenu.change_tag_script = function (key) {
  if ($("#mode-box-mode").val() !== "tag-script")
    return;

  const newScriptID = Number(key);
  if (!newScriptID || newScriptID == LStorage.Posts.TagScript.ID)
    return;

  LStorage.Posts.TagScript.ID = newScriptID;
  $("#tag-script-field").val(LStorage.Posts.TagScript.Content);
  PostModeMenu.show_notice(newScriptID);
};

PostModeMenu.initialize_selector = function () {
  $("#mode-box-mode").val(SStorage.Posts.Mode);

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
  $("#quick-edit-form #quick-edit-cancel").on("click.danbooru", function (e) {
    PostModeMenu.close_edit_form();
    e.preventDefault();
  });

  $("#quick-edit-form").on("submit.danbooru", function (event) {
    event.preventDefault();

    PendingUpdates.track(PostModel.update(PostModeMenu.editing_post_id, { tag_string: $("#post_tag_string").val() }))
      .then((data) => {
        BulkActions.syncThumbnail(data);
        ToastManager.notice("Post #" + data.id + " updated");
        PostModeMenu.close_edit_form();
      })
      .catch(() => { /* Reported through danbooru:error */ })
      .finally(() => {
        Rails.enableElement(document.getElementById("quick-edit-form"));
      });

    return false;
  });
};

PostModeMenu.close_edit_form = function () {
  Hotkeys.enabled = true;
  $("#quick-edit-div").slideUp("fast");
  if (CurrentUser.settings.autocomplete) {
    const field = document.getElementById("post_tag_string");
    const autocompleter = Autocomplete.instances.get(field);
    if (autocompleter) autocompleter.close();
  }
};

PostModeMenu.initialize_tag_script_field = function () {
  $("#tag-script-field").on("blur", function () {
    const script = $(this).val();
    LStorage.Posts.TagScript.Content = script;
    PostModeMenu.parse_tag_script(script);
  });

  $("#tag-script-all").on("click", PostModeMenu.tag_script_apply_all);
};

PostModeMenu.tag_script_apply_all = function (event) {
  event.preventDefault();
  if (!PostModeMenu.parse_tag_script(LStorage.Posts.TagScript.Content)) return;
  const posts = $("article.thumbnail");
  if (!confirm(`Apply the tag script to ${posts.length} posts?`)) return;
  posts.trigger("click");
};

/** Returns the parsed commands, or null (with an alert) if the script is invalid */
PostModeMenu.parse_tag_script = function (script) {
  try {
    return TagScript.parse(script);
  } catch (error) {
    if (!(error instanceof TagScriptError)) throw error;
    ToastManager.alert(error.message);
    return null;
  }
};

PostModeMenu.update_sets_menu = function () {
  return PostSet.populateSelect($("#set-id"));
};

PostModeMenu.change = function () {
  $("#quick-edit-div").slideUp("fast");
  const s = $("#mode-box-mode").val();
  if (s === undefined) {
    return;
  }
  $("#page").attr("data-mode-menu", s);
  SStorage.Posts.Mode = s;
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

PostModeMenu.editing_post_id = null;
PostModeMenu.open_edit = function (post_id) {
  Hotkeys.enabled = false;
  PostModeMenu.editing_post_id = post_id;
  var $post = $(`article.thumbnail[data-id="${post_id}"]`).first();
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
    PendingUpdates.track(Favorite.create(post_id)).catch(() => { /* Reported through danbooru:error */ });
  } else if (s === "remove-fav") {
    PendingUpdates.track(Favorite.destroy(post_id)).catch(() => { /* Reported through danbooru:error */ });
  } else if (s === "edit") {
    PostModeMenu.open_edit(post_id);
  } else if (s === "vote-down") {
    PendingUpdates.track(PostVote.vote(post_id, -1, true)).catch(() => { /* Reported through danbooru:error */ });
  } else if (s === "vote-up") {
    PendingUpdates.track(PostVote.vote(post_id, 1, true)).catch(() => { /* Reported through danbooru:error */ });
  } else if (s === "add-to-set") {
    PostSet.add_post($("#set-id").val(), post_id);
  } else if (s === "remove-from-set") {
    PostSet.remove_post($("#set-id").val(), post_id);
  } else if (s === "rating-q") {
    BulkActions.update(post_id, { rating: "q" });
  } else if (s === "rating-s") {
    BulkActions.update(post_id, { rating: "s" });
  } else if (s === "rating-e") {
    BulkActions.update(post_id, { rating: "e" });
  } else if (s === "lock-rating") {
    BulkActions.update(post_id, { is_rating_locked: "1" });
  } else if (s === "lock-note") {
    BulkActions.update(post_id, { is_note_locked: "1" });
  } else if (s === "delete") {
    BulkActions.delete(post_id, $("#quick-mode-reason").val());
  } else if (s === "undelete") {
    BulkActions.undelete(post_id);
  } else if (s === "unflag") {
    BulkActions.unflag(post_id, "none");
  } else if (s === "approve") {
    BulkActions.approve(post_id);
  } else if (s === "remove-parent") {
    BulkActions.update(post_id, { parent_id: "" });
  } else if (s === "tag-script") {
    // Never fall through to the post link, even on a broken script
    e.preventDefault();
    const commands = PostModeMenu.parse_tag_script(LStorage.Posts.TagScript.Content);
    const post = PostCache.get(post_id);
    if (!commands || !post) return;

    const changes = TagScript.evaluate(commands, post.tagSet);
    if (changes.length) BulkActions.applyTagDiff(post_id, changes, $("#tag-script-reason").val());
  } else {
    return;
  }

  e.preventDefault();
};

$(function () {
  PostModeMenu.initialize();
});

export default PostModeMenu;
