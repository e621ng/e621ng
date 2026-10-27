import ApiRequest from "@/utility/ApiRequest";

export type PostDisapprovalJSON = Record<string, any>;

export default class PostApproval {

  static create (post_id: number): Promise<void> {
    return ApiRequest.send("/staff/post/approval.json", {
      method: "POST",
      json: { post_id },
      queue: { name: "Post.approve" },
    }).then(() => undefined);
  }

  static destroy (post_id: number): Promise<void> {
    return ApiRequest.send("/staff/post/approval.json", {
      method: "DELETE",
      json: { post_id },
      queue: { name: "Post.unapprove" },
    }).then(() => undefined);
  }

  // The backend answers 200 with the record even when validation fails.
  static disapprove (post_id: number, reason: string, message?: string): Promise<PostDisapprovalJSON> {
    return ApiRequest.json("/staff/post/disapprovals.json", {
      method: "POST",
      json: { post_disapproval: { post_id, reason, message } },
      queue: { name: "Post.disapprove" },
    });
  }
}
