import ThumbnailEngine from "@/components/ThumbnailEngine";
import PostCache from "@/models/PostCache";

$(() => {
  const avatar = $(".profile-avatar.placeholder").first();
  if (!avatar.length) return;
  avatar.removeClass("placeholder"); // don't reload no matter what

  const postID = avatar.data("id");
  if (!postID) return;
  const post = PostCache.get(postID);
  if (!post || !post.preview_url) return;

  const placeholder = avatar.find(".avatar-image");
  const thumbnail = ThumbnailEngine.render(post, { showStatistics: false });
  thumbnail.find("a.thm-link").attr("data-initial", placeholder.data("initial") || "?");
  placeholder.replaceWith(thumbnail);
});
