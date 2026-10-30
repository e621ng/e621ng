import ApiRequest from "@/utility/ApiRequest";

export interface TakedownAddResponse {
  added_count: number;
  added_post_ids: number[];
}

/** Post list endpoints used by the takedown editor. Failures are reported via ApiRequest. */
export default class Takedown {

  /** Number of non-deleted posts matching the tags, i.e. what addPostsByTags would consider */
  static countMatchingPosts (tags: string): Promise<number> {
    return ApiRequest.json<{ matched_post_count: number }>("/takedowns/count_matching_posts.json", {
      method: "POST",
      json: { post_tags: tags },
      queue: { name: "Takedown.countMatchingPosts" },
    }).then((data) => data.matched_post_count);
  }

  static addPostsByTags (id: number, tags: string): Promise<TakedownAddResponse> {
    return ApiRequest.json(`/takedowns/${id}/add_by_tags.json`, {
      method: "POST",
      json: { post_tags: tags },
      queue: { name: "Takedown.addPostsByTags" },
    });
  }

  /** @param ids Space-separated post IDs or post URLs, parsed server-side */
  static addPostsByIds (id: number, ids: string): Promise<TakedownAddResponse> {
    return ApiRequest.json(`/takedowns/${id}/add_by_ids.json`, {
      method: "POST",
      json: { post_ids: ids },
      queue: { name: "Takedown.addPostsByIds" },
    });
  }

  static removePost (id: number, postId: number): Promise<void> {
    return ApiRequest.send(`/takedowns/${id}/remove_by_ids.json`, {
      method: "POST",
      json: { post_ids: String(postId) },
      queue: { name: "Takedown.removePost" },
    }).then(() => undefined);
  }

  /** Removes every post from the takedown; resolves with the number removed */
  static clearPosts (id: number): Promise<number> {
    return ApiRequest.json<{ removed_count: number }>(`/takedowns/${id}/clear_posts.json`, {
      method: "POST",
      queue: { name: "Takedown.clearPosts" },
    }).then((data) => data.removed_count);
  }
}
