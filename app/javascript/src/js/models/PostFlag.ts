import ApiRequest from "@/utility/ApiRequest";

export type PostFlagJSON = Record<string, any>;

export interface PostFlagParams {
  reason_name: string;
  parent_id?: number | null;
  note?: string | null;
}

export default class PostFlag {

  static create (post_id: number, params: PostFlagParams): Promise<PostFlagJSON> {
    return ApiRequest.json("/post_flags.json", {
      method: "POST",
      json: { post_flag: { post_id, ...params } },
      queue: { name: "Post.flag" },
    });
  }

  /**
   * Removes the pending flag. Pass `approval: "approve"` to approve the post in the same request.
   */
  static destroy (post_id: number, approval: string = "none"): Promise<void> {
    return ApiRequest.send(`/posts/${post_id}/flag.json`, {
      method: "DELETE",
      json: { approval },
      queue: { name: "Post.unflag" },
    }).then(() => undefined);
  }
}
