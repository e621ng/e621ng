import E621Type from "@/interfaces/E621";
import CurrentPost from "@/models/CurrentPost";
import TaskQueue, { TaskCancelled } from "@/utility/TaskQueue";

declare const E621: E621Type;

export default class PostVote {

  /**
   * Upvote a post.
   * @param {number} postID ID of the post to upvote.
   */
  static up (postID: number = null) {
    if (!postID) {
      if (!CurrentPost.exists) throw new Error("No current post available for voting.");
      postID = CurrentPost.id;
    }
    this.vote(postID, 1);
  }

  /**
   * Downvote a post.
   * @param {number} postID ID of the post to downvote.
   */
  static down (postID: number = null) {
    if (!postID) {
      if (!CurrentPost.exists) throw new Error("No current post available for voting.");
      postID = CurrentPost.id;
    }
    this.vote(postID, -1);
  }

  /**
   * Cast a vote on a post.
   * @param {number} post_id ID of the post to vote on.
   * @param {number} vote The vote score (1 for upvote, -1 for downvote).
   * @param {boolean} prevent_unvote If true, prevents unvoting.
   * @returns {Promise<Object>} The response from the server.
   */
  static async vote (post_id: number, vote: number, prevent_unvote: boolean = false): Promise<object> {
    return TaskQueue.add(() => {
      return fetch(`/posts/${post_id}/votes.json`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "accept": "*/*;q=0.5,text/javascript",
        },
        credentials: "include",
        mode: "cors",
        body: JSON.stringify({
          score: vote,
          no_unvote: prevent_unvote,
          authenticity_token: E621.CurrentUser.encodedAuthToken,
        }),
      });
    }, { name: `Post.vote.${post_id}`, unique: true, delay: 500 }).then(async (response) => {
      if (!response.ok)
        return response.json().then((data) => {
          const message = data.reason || data.message || "An error occurred while voting.";
          $(window).trigger("danbooru:error", message);
          throw new Error(message);
        });

      return response.json();
    }, (error) => {
      if (error instanceof TaskCancelled) return Promise.reject(error);

      console.error(error);
      if (error.status === 403)
        $(window).trigger("danbooru:error", "Permission denied.");
      else if (error.status === 404)
        $(window).trigger("danbooru:error", "Post not found.");
      else
        $(window).trigger("danbooru:error", "Error: " + error.message);
      return Promise.reject();
    });
  }

}
