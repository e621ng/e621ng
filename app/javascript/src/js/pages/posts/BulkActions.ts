import Post, { PostThumbnailJSON, PostUpdateParams } from "@/models/Post";
import PostApproval from "@/models/PostApproval";
import PostFlag from "@/models/PostFlag";
import PendingUpdates from "@/pages/posts/PendingUpdates";
import { ApiError } from "@/utility/ApiRequest";
import Page from "@/utility/Page";
import ToastManager from "@/utility/Toast";

export interface BulkDeleteOptions {
  reload?: boolean;
  from_flag?: boolean;
  move_favorites?: boolean;
  dmail?: string | null;
  dmail_title?: string | null;
}

const STATUS_FLAGS = ["pending", "flagged", "deleted"];
const RATING_CLASSES: Record<string, string> = { s: "rating-safe", q: "rating-questionable", e: "rating-explicit" };

// Request failures are already reported through `danbooru:error` by the models.
const reported = () => { /* Reported through danbooru:error */ };

/**
 * Post actions applied from the index mode menu and the mod queue. Each one
 * counts towards the pending-updates toast and keeps the matching thumbnails
 * in sync. Exposed as `E621.Post` on the index and favorites pages.
 */
export default class BulkActions {

  static update (post_id: number, params: PostUpdateParams): Promise<void> {
    return PendingUpdates.track(Post.update(post_id, params))
      .then((data) => { BulkActions.syncThumbnail(data); })
      .catch(reported);
  }

  static tagScript (post_id: number, tags: string | string[], reason: string = ""): Promise<void> {
    const tag_string = Array.isArray(tags) ? tags.join(" ") : String(tags);
    return BulkActions.update(post_id, { tag_string_diff: tag_string, edit_reason: reason });
  }

  static delete (post_id: number, reason: string, options: BulkDeleteOptions = {}): Promise<void> {
    const { reload = false, from_flag = false, move_favorites = false, dmail = null, dmail_title = null } = options;
    return PendingUpdates.track(Post.delete(post_id, { reason, from_flag, move_favorites, dmail, dmail_title }))
      .then(() => {
        ToastManager.notice("Deleted post.");
        if (reload) BulkActions.reload();
        else BulkActions.setFlags(BulkActions.thumbnails(post_id), "deleted");
      })
      .catch((error) => {
        // Already deleted elsewhere: the page is stale
        if (error instanceof ApiError && error.status === 409) BulkActions.reload();
      });
  }

  static undelete (post_id: number): Promise<void> {
    return PendingUpdates.track(Post.undelete(post_id))
      .then(() => {
        BulkActions.setFlags(BulkActions.thumbnails(post_id), "");
        ToastManager.notice("Undeleted post.");
      })
      .catch(reported);
  }

  static unflag (post_id: number, approval: string = "none"): Promise<void> {
    return PendingUpdates.track(PostFlag.destroy(post_id, approval))
      .then(() => {
        BulkActions.removeFlag(BulkActions.thumbnails(post_id), "flagged");
        ToastManager.notice("Unflagged post");
      })
      .catch(reported);
  }

  static approve (post_id: number): Promise<void> {
    return PendingUpdates.track(PostApproval.create(post_id))
      .then(() => {
        const $thumbnails = BulkActions.thumbnails(post_id);
        if (!$thumbnails.length) return;
        BulkActions.removeFlag($thumbnails, "pending");
        ToastManager.notice("Approved post #" + post_id);
      })
      .catch(reported);
  }

  static disapprove (post_id: number, reason: string, message?: string): Promise<void> {
    return PendingUpdates.track(PostApproval.disapprove(post_id, reason, message))
      .then(() => {
        if (Page.matches("posts", "show")) BulkActions.reload();
      })
      .catch(reported);
  }

  /** Applies a thumbnails-mode post payload to every thumbnail of that post on the page. */
  static syncThumbnail (data: PostThumbnailJSON): JQuery<HTMLElement> {
    const $thumbnails = BulkActions.thumbnails(data.id);
    if (!$thumbnails.length) return $thumbnails;

    BulkActions.setData($thumbnails, "tags", data.tags);
    BulkActions.setData($thumbnails, "rating", data.rating);
    BulkActions.setFlags($thumbnails, data.flags);

    $thumbnails.removeClass(Object.values(RATING_CLASSES).join(" "));
    if (RATING_CLASSES[data.rating]) $thumbnails.addClass(RATING_CLASSES[data.rating]);

    return $thumbnails;
  }

  static thumbnails (post_id: number): JQuery<HTMLElement> {
    return $(`article.thumbnail[data-id="${post_id}"]`);
  }

  private static setFlags ($thumbnails: JQuery<HTMLElement>, flags: string): void {
    BulkActions.setData($thumbnails, "flags", flags);
    const active = new Set(flags.split(" ").filter((flag) => flag));
    for (const flag of STATUS_FLAGS) $thumbnails.toggleClass(flag, active.has(flag));
    // The blacklist picks the attribute changes up through PostCache's observer
  }

  private static removeFlag ($thumbnails: JQuery<HTMLElement>, flag: string): void {
    const flags = String($thumbnails.first().attr("data-flags") ?? "").split(" ").filter((f) => f && f !== flag);
    BulkActions.setFlags($thumbnails, flags.join(" "));
  }

  // Both the attribute (CSS, selectors) and jQuery's data cache (what the mode menu reads)
  private static setData ($thumbnails: JQuery<HTMLElement>, key: string, value: string): void {
    $thumbnails.attr(`data-${key}`, value).data(key, value);
  }

  private static reload (): void {
    location.reload();
  }
}
