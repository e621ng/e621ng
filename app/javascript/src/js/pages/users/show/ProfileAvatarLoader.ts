import ThumbnailEngine from "@/components/ThumbnailEngine";
import E621Type from "@/interfaces/E621";
import PostCache from "@/models/PostCache";

declare const E621: E621Type;

$(() => {
  const avatar = $(".profile-avatar.placeholder").first();
  if (!avatar.length) return;
  avatar.removeClass("placeholder"); // don't reload no matter what

  const postID = avatar.data("id");
  if (!postID) return;
  const post = PostCache.get(postID);
  if (!post || !post.preview_url) return;

  const thumbnail = ThumbnailEngine.render(post, { showStatistics: false });
  if (!thumbnail) return; // .render returns null if the post data is invalid
  thumbnail.find("a.thm-link").attr("data-initial", avatar.data("initial") || "?");

  const attachment = avatar.find(".avatar-image");
  if (attachment.length) attachment.replaceWith(thumbnail);
  else avatar.html("").append(thumbnail);
});
