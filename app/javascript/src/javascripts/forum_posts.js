import Utility from "./utility";
import Comment from "./comments";

let ForumPost = {};

ForumPost.initialize_all = function() {
  if ($("#c-forum-topics #a-show,#c-forum-posts #a-show").length) {
    this.initialize_edit_links();
    $(".forum-post-reply-link").on('click', ForumPost.quote);
    $(".forum-post-hide-link").on('click', ForumPost.hide);
    $(".forum-post-unhide-link").on('click', ForumPost.unhide);
  }
}

ForumPost.quote = function (e) {
  e.preventDefault();
  const parent = $(e.target).parents('article.forum-post');
  const fpid = parent.data('forum-post-id');
  $.ajax({
    url: `/forum_posts/${fpid}.json`,
    type: 'GET',
    dataType: 'json',
    accept: 'text/javascript'
  }).done(function (data) {
    let stripped_body = data.body.replace(/\[quote\](?:.|\n|\r)+?\[\/quote\][\n\r]*/gm, "");
    stripped_body = `[quote]"${parent.data('creator')}":/user/show/${parent.data('creator-id')} said:
${stripped_body}
[/quote]

`;
    var $textarea = $('#forum_post_body');
    var msg = stripped_body;
    if ($textarea.val().length > 0) {
      msg = $textarea.val() + "\n\n" + msg;
    }

    $textarea.val(msg);
    $textarea.selectEnd();
    $('#topic-response').show();
    setTimeout(function() {
      $('#topic-response')[0].scrollIntoView();
    }, 15);
  }).fail(function (data) {
    Utility.error(data.responseText);
  });
};

ForumPost.hide = function (e) {
  e.preventDefault();
  if (!confirm("Are you sure you want to hide this post?"))
    return;
  const parent = $(e.target).parents('article.forum-post');
  const fpid = parent.data('forum-post-id');
  $.ajax({
    url: `/forum_posts/${fpid}/hide.json`,
    type: 'POST',
    dataType: 'json'
  }).done(function (data) {
    $(`.forum-post[data-forum-post-id="${fpid}"] div.author h4`).append(" (hidden)");
    $(`.forum-post[data-forum-post-id="${fpid}"]`).attr('data-is-deleted', 'true');
  }).fail(function (data) {
    Utility.error("Failed to hide post.");
  });
};

ForumPost.unhide = function (e) {
  e.preventDefault();
  if (!confirm("Are you sure you want to unhide this post?"))
    return;
  const parent = $(e.target).parents('article.forum-post');
  const fpid = parent.data('forum-post-id');
  $.ajax({
    url: `/forum_posts/${fpid}/unhide.json`,
    type: 'POST',
    dataType: 'json'
  }).done(function (data) {
    const $author = $(`.forum-post[data-forum-post-id="${fpid}"] div.author h4`);
    $author.text($author.text().replace(" (hidden)", ""));
    $(`.forum-post[data-forum-post-id="${fpid}"]`).attr('data-is-deleted', 'false');
  }).fail(function (data) {
    Utility.error("Failed to unhide post.");
  });
};

ForumPost.initialize_edit_links = function() {
  $(".edit_forum_post_link").on("click.danbooru", function(e) {
    var link_id = $(this).attr("id");
    var forum_post_id = link_id.match(/^edit_forum_post_link_(\d+)$/)[1];
    $("#edit_forum_post_" + forum_post_id).fadeToggle("fast");
    e.preventDefault();
  });

  $(".edit_forum_topic_link").on("click.danbooru", function(e) {
    var link_id = $(this).attr("id");
    var forum_topic_id = link_id.match(/^edit_forum_topic_link_(\d+)$/)[1];
    $("#edit_forum_topic_" + forum_topic_id).fadeToggle("fast");
    e.preventDefault();
  });
}

$(document).ready(function() {
  ForumPost.initialize_all();
});

export default ForumPost
