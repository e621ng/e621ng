import Utility from './utility'
import Post from './posts'
import LS from './local_storage';

let ModQueue = {};

ModQueue.detailed_rejection_dialog = function() {
  const postID = $(this).data("post-id");
  $("#post_disapproval_post_id").val(postID);
  $("#detailed-rejection-dialog").find("form")[0].reset();

  $("#new_post_disapproval")
    .off("submit.danbooru")
    .on("submit.danbooru", () => {
      Post.disapprove(postID, $("#post_disapproval_reason").val(), $("#post_disapproval_message").val())
      return false;
    });

  Utility.dialog("Detailed Rejection", "#detailed-rejection-dialog");
  return false;
}

$(function() {
  // Toolbar visibility
  let toolbarVisible = LS.get("jtb") == "true";
  const toolbar = $("#pending-approval-notice");
  if(toolbarVisible) toolbar.addClass("enabled");

  const toolbarToggle = $("#janitor-toolbar-toggle")
    .on("click", (event) => {
      event.preventDefault();
      toolbarVisible = !toolbarVisible;
      LS.put("jtb", toolbarVisible);

      toolbar.toggleClass("enabled");
      toolbarToggle.text(toolbarVisible ? "Approvals: On" : "Approvals: Off");
      
      return false;
    })
    .text(toolbarVisible ? "Approvals: On" : "Approvals: Off");

  // Toolbar buttons
  $(document).on("click.danbooru", ".quick-mod .detailed-rejection-link", ModQueue.detailed_rejection_dialog);
  $(".delete-with-reason-link").on('click', function(e) {
    e.preventDefault();
    const post_id = $(e.target).attr('data-post-id');
    const prompt = $(e.target).data('prompt');
    const reason = $(e.target).data('reason');

    if (confirm(`Delete post for ${prompt}?`))
      Post.delete_with_reason(post_id, reason, true);
  });
});

export default ModQueue
