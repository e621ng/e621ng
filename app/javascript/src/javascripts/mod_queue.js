import Post from "./posts";
import LStorage from "./utility/storage";
import Dialog from "./utility/dialog";

let ModQueue = {};

let rejectionDialog = null;
ModQueue.detailed_rejection_dialog = function () {
  if (rejectionDialog == null) {
    // Initialize the dialog
    rejectionDialog = new Dialog("#detailed-rejection-dialog");

    // Fill in the form data
    const postID = $(this).data("post-id");
    $("#post_disapproval_post_id").val(postID);
    $("#detailed-rejection-dialog").find("form")[0].reset();

    $("#new_post_disapproval")
      .off("submit.danbooru")
      .on("submit.danbooru", (event) => {
        event.preventDefault();
        Post.disapprove(postID, $("#post_disapproval_reason").val(), $("#post_disapproval_message").val());
        rejectionDialog.close();
        return false;
      });

    $("#detailed-rejection-cancel").on("click", (event) => {
      event.preventDefault();
      rejectionDialog.close();
    });
  }

  rejectionDialog.toggle();
  return false;
};

$(function () {
  if (!$("body").data("user-is-approver")) return;

  // Toolbar visibility
  let toolbarVisible = LStorage.Posts.JanitorToolbar;
  const toolbar = $("#pending-approval-notice");
  if (toolbarVisible) toolbar.addClass("enabled");

  const toolbarToggle = $("#janitor-toolbar-toggle")
    .on("click", (event) => {
      event.preventDefault();
      toolbarVisible = !toolbarVisible;
      LStorage.Posts.JanitorToolbar = toolbarVisible;

      toolbar.toggleClass("enabled");
      toolbarToggle.text(toolbarVisible ? "Approvals: On" : "Approvals: Off");

      return false;
    })
    .text(toolbarVisible ? "Approvals: On" : "Approvals: Off");

  // Toolbar buttons
  $(document).on("click.danbooru", ".quick-mod .detailed-rejection-link", ModQueue.detailed_rejection_dialog);


  $(".delete-with-reason-link").on("click", function (event) {
    event.preventDefault();
    const data = event.target.dataset;
    if (!confirm(`Delete post for ${data.prompt}?`)) return;
    Post.delete_with_reason(data.postId, data.reason, { reload_after_delete: true, move_favorites: data.moveFavs === "true" });
  });
});

export default ModQueue;
