import CurrentPost from "@/models/CurrentPost";
import CurrentUser from "@/models/CurrentUser";
import Post from "@/models/Post";
import PostApproval from "@/models/PostApproval";
import PostFlag from "@/models/PostFlag";
import ToastManager from "@/utility/Toast";

const pid = (event: JQuery.TriggeredEvent): number => Number($(event.currentTarget).data("pid"));

// Request failures are already reported through `danbooru:error` by the models.
const reported = () => { /* Reported through danbooru:error */ };

/**
 * The moderation and option links in the posts#show sidebar and notices:
 * approve, unflag, undelete, destroy, regenerate samples, set avatar, copy notes.
 */
export default class PostActions {

  static bind (): void {
    $(".undelete-post-link").on("click.danbooru", (event) => {
      event.preventDefault();
      if (!confirm("Are you sure you want to undelete this post?")) return;
      Post.undelete(pid(event))
        .then(() => {
          ToastManager.notice("Undeleted post.");
          PostActions.reload();
        })
        .catch(reported);
    });

    $(".approve-post-link").on("click.danbooru", (event) => {
      event.preventDefault();
      PostApproval.create(pid(event))
        .then(() => PostActions.reload())
        .catch(reported);
    });

    $(".approve-post-and-navigate-link").on("click.danbooru", (event) => {
      event.preventDefault();
      const location = String($(event.currentTarget).data("location"));
      PostApproval.create(pid(event))
        .then(() => PostActions.navigate(location))
        .catch(reported);
    });

    $("#unapprove-post-link").on("click.danbooru", (event) => {
      event.preventDefault();
      PostApproval.destroy(pid(event))
        .then(() => {
          ToastManager.notice("Unapproved post.");
          PostActions.reload();
        })
        .catch(reported);
    });

    $(".disapprove-post-link").on("click.danbooru", (event) => {
      event.preventDefault();
      PostApproval.disapprove(pid(event), String($(event.currentTarget).data("reason")))
        .then(() => PostActions.reload())
        .catch(reported);
    });

    $(".unflag-post-link").on("click.danbooru", (event) => {
      event.preventDefault();
      PostFlag.destroy(pid(event), String($(event.currentTarget).data("type") || "none"))
        .then(() => {
          ToastManager.notice("Unflagged post");
          PostActions.reload();
        })
        .catch(reported);
    });

    $(".move-flag-to-parent-link").on("click.danbooru", (event) => {
      event.preventDefault();
      const $link = $(event.currentTarget);
      const post_id = pid(event);
      const parent_id = Number($link.data("parent-id"));
      const reason_name = String($link.data("reason-name"));
      const note = $link.data("note") ?? null;

      if (!confirm("Move flag to parent?")) return;
      PostFlag.destroy(post_id, "none")
        .then(() => PostFlag.create(parent_id, { reason_name, parent_id: post_id, note }))
        .then(() => PostActions.navigate(`/staff/post/posts/${parent_id}/confirm_delete`))
        .catch(reported);
    });

    $("#destroy-post-link").on("click.danbooru", (event) => {
      event.preventDefault();
      const reason = prompt("This will permanently delete this post (meaning the file will be deleted). What is the reason for destroying the post?");
      if (reason === null) return;
      const post_id = pid(event);
      Post.expunge(post_id, reason)
        .then(() => PostActions.navigate(`/staff/destroyed_posts/${post_id}`))
        .catch(reported);
    });

    $("#regenerate-image-samples-link").on("click.danbooru", (event) => {
      event.preventDefault();
      Post.regenerateImageSamples(pid(event))
        .then(() => {
          if ($("#image-container").data("size") >= 10 * 1024 * 1024)
            ToastManager.notice("Large file: Image samples will be regenerated soon.");
          else
            ToastManager.notice("Image samples regenerated successfully.");
        })
        .catch(reported);
    });

    $("#regenerate-video-samples-link").on("click.danbooru", (event) => {
      event.preventDefault();
      Post.regenerateVideoSamples(pid(event))
        .then(() => ToastManager.notice("Video samples will be regenerated in a few minutes."))
        .catch(reported);
    });

    $("#set-as-avatar-link").on("click.danbooru", (event) => {
      event.preventDefault();
      if (!confirm("Set post as avatar?")) return;
      CurrentUser.setAvatar(Number($(event.currentTarget).data("post-id")))
        .then(() => ToastManager.notice("Post set as avatar. You can crop it further <a href='/maintenance/user/avatar/edit'>here</a>."))
        .catch(reported);
    });

    $("#copy-notes").on("click.danbooru", (event) => {
      event.preventDefault();
      const other_post_id = parseInt(prompt("Enter the ID of the post to copy all notes to:"), 10);
      if (isNaN(other_post_id)) return;
      Post.copyNotes(CurrentPost.id, other_post_id)
        .then(() => ToastManager.notice("Successfully copied notes to <a href='" + other_post_id + "'>post #" + other_post_id + "</a>"))
        .catch(reported);
    });
  }

  private static reload (): void {
    location.reload();
  }

  private static navigate (href: string): void {
    location.href = href;
  }
}
