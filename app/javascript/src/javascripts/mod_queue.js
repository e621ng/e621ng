import Utility from './utility'
import Post from './posts'

let ModQueue = {};

ModQueue.detailed_rejection_dialog = function() {
  $("#post_disapproval_post_id").val($(this).data("post-id"));
  $("#detailed-rejection-dialog").find("form")[0].reset();

  Utility.dialog("Detailed Rejection", "#detailed-rejection-dialog");
  return false;
}

$(function() {
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
