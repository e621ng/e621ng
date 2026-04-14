import Post from "@/pages/posts/posts";
import LStorage from "@/utility/storage";
import Dialog from "@/utility/dialog";

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

let deletionDialog = null;
ModQueue.delete_with_reason_dialog = function (event) {
  const form = $("#delete-with-reason-dialog");
  if (deletionDialog == null) {
    deletionDialog = new Dialog("#delete-with-reason-dialog");
    $("#delete-with-reason-dialog-cancel").on("click", () => deletionDialog.close());
    $(document).on("keydown", (event) => {
      // .isFocused would make more sense if it existed
      if (event.key === "Enter" && deletionDialog.isOpen) {
        event.preventDefault();
        form.trigger("submit");
      }
    });
  }

  const data = event.currentTarget.dataset;
  const hasReason = data.fromFlag !== "true";
  const reason = data.reason;

  const reasonInput = $("#delete-with-reason-dialog-input");
  reasonInput.val(reason);
  reasonInput[0].style.display = hasReason ? "" : "none";

  form.off("submit").on("submit", (event) => {
    event.preventDefault();
    const dmailOption = $("#delete-with-reason-dialog-enable-dmail");
    // Absent if no DMail template is configured
    const sendDMail = dmailOption?.prop("checked");
    const dmailMessage = sendDMail ? dmailOption?.attr("data-dmail-message") : null;
    const dmailTitle = sendDMail ? dmailOption?.attr("data-dmail-title") : null;
    const finalReason = hasReason ? reasonInput.val() : reason;
    Post.delete_with_reason(data.postId, finalReason, {
      reload_after_delete: true,
      from_flag: !hasReason,
      move_favorites: data.moveFavs === "true",
      dmail: dmailMessage,
      dmail_title: dmailTitle,
    });
    return false;
  });

  deletionDialog.open();

  // Scroll to end of reason so it's faster to append to it
  reasonInput.scrollLeft(reasonInput[0].scrollWidth);

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
  $(".delete-with-reason-link").on("click", ModQueue.delete_with_reason_dialog);
});

export default ModQueue;
