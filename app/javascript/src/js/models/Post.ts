import ApiRequest from "@/utility/ApiRequest";

/** Full post JSON as rendered by the responders / legacy blueprints. Kept loose for now. */
export type PostJSON = Record<string, any>;

/** PUT /posts/:id.json still answers in the legacy `{ post: {...} }` envelope. */
export interface PostUpdateResponse {
  post: PostJSON;
}

export interface PostUpdateParams {
  tag_string?: string;
  old_tag_string?: string;
  tag_string_diff?: string;
  source?: string;
  old_source?: string;
  source_diff?: string;
  description?: string;
  old_description?: string;
  rating?: "s" | "q" | "e";
  old_rating?: string;
  parent_id?: number | string | null;
  old_parent_id?: number | string | null;
  is_rating_locked?: boolean | string;
  is_note_locked?: boolean | string;
  edit_reason?: string;
  // Remaining staff-only attributes accepted by PostsController#post_params
  [key: string]: string | number | boolean | null | undefined;
}

export interface PostDeleteOptions {
  reason: string;
  from_flag?: boolean;
  move_favorites?: boolean;
  dmail?: string | null;
  dmail_title?: string | null;
}

export default class Post {

  static update (post_id: number, params: PostUpdateParams): Promise<PostUpdateResponse> {
    return ApiRequest.json(`/posts/${post_id}.json`, {
      method: "PUT",
      json: { post: params },
      queue: { name: "Post.update" },
      errorText: (error) => `There was an error updating <a href="/posts/${post_id}">post #${post_id}</a>: ${error.message}`,
    });
  }

  /**
   * Deletes a post with a reason. Rejects with an ApiError of status 409 if the post
   * is already deleted. A blank reason makes the backend redirect to the confirmation
   * page, which surfaces here as a JSON parse failure.
   */
  static delete (post_id: number, options: PostDeleteOptions): Promise<PostJSON> {
    return ApiRequest.json(`/staff/post/posts/${post_id}/delete.json`, {
      method: "POST",
      json: {
        commit: "Delete",
        reason: options.reason,
        from_flag: !!options.from_flag,
        move_favorites: !!options.move_favorites,
        dmail: options.dmail ?? null,
        dmail_title: options.dmail_title ?? null,
      },
      queue: { name: "Post.delete_with_reason" },
    });
  }

  static undelete (post_id: number): Promise<PostJSON> {
    return ApiRequest.json(`/staff/post/posts/${post_id}/undelete.json`, {
      method: "POST",
      queue: { name: "Post.undelete" },
    });
  }

  /** Permanently destroys the post and its file. */
  static expunge (post_id: number, reason: string): Promise<PostJSON> {
    return ApiRequest.json(`/staff/post/posts/${post_id}/expunge.json`, {
      method: "POST",
      json: { reason },
    });
  }

  static regenerateImageSamples (post_id: number): Promise<PostJSON> {
    return ApiRequest.json(`/staff/post/posts/${post_id}/regenerate_thumbnails.json`, { method: "POST" });
  }

  static regenerateVideoSamples (post_id: number): Promise<PostJSON> {
    return ApiRequest.json(`/staff/post/posts/${post_id}/regenerate_videos.json`, { method: "POST" });
  }

  /** Copies all notes from this post onto another one. */
  static copyNotes (post_id: number, other_post_id: number): Promise<void> {
    return ApiRequest.send(`/posts/${post_id}/copy_notes.json`, {
      method: "PUT",
      json: { other_post_id },
      errorText: (error) => (error.status === 404 ? "Error: Invalid destination post" : "Error: " + error.message),
    }).then(() => undefined);
  }
}
