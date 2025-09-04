import TaskQueue from "../utility/task_queue";
import User from "./User";
import Post from "../posts";

export default class PostVote {

  /**
   * Upvote a post.
   * @param {number} postID ID of the post to upvote.
   */
  static up (postID = null) {
    if (!postID) postID = Post.currentPost().id;
    this.vote(postID, 1);
  }

  /**
   * Downvote a post.
   * @param {number} postID ID of the post to downvote.
   */
  static down (postID = null) {
    if (!postID) postID = Post.currentPost().id;
    this.vote(postID, -1);
  }

  /**
   * Cast a vote on a post.
   * @param {number} post_id ID of the post to vote on.
   * @param {number} vote The vote score (1 for upvote, -1 for downvote).
   * @param {boolean} prevent_unvote If true, prevents unvoting.
   * @returns {Promise<Object>} The response from the server.
   */
  static async vote (post_id, vote, prevent_unvote = false) {
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
          authenticity_token: encodeURIComponent(User._authToken),
        }),
      });
    }).then(async (response) => {
      if (!response.ok)
        return response.json().then((data) => {
          const message = data.reason || data.message || "An error occurred while voting.";
          $(window).trigger("danbooru:error", message);
          throw new Error(message);
        });

      return response.json();
    }, (error) => {
      console.error(error);
      if (error.status === 403)
        $(window).trigger("danbooru:error", "Permission denied.");
      else if (error.status === 404)
        $(window).trigger("danbooru:error", "Post not found.");
      else
        $(window).trigger("danbooru:error", "Error: " + error.message);
      return Promise.reject();
    });
  };

}
