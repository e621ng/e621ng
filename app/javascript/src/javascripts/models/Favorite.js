import TaskQueue, { TaskCancelled } from "../utility/task_queue";
import User from "./User";

export default class Favorite {

  /**
   * Creates a new favorite for the specified post.
   * @param {number} post_id The ID of the post to favorite.
   * @returns {Promise<Response>} The response from the server.
   */
  static async create (post_id, delay = 1000) {
    if (!post_id) return Promise.reject(new Error("Post ID is required"));

    return TaskQueue.add(async () => {
      return fetch("/favorites.json", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "accept": "*/*;q=0.5,text/javascript",
        },
        mode: "cors",
        credentials: "include",
        body: JSON.stringify({
          post_id: post_id,
          authenticity_token: encodeURIComponent(User._authToken),
        }),
      });
    }, { name: `Post.favorite.${post_id}`, unique: true, delay: delay }).then(async (response) => {
      if (!response.ok) {
        console.log("Response not OK:", response.status, response.statusText);
        try {
          const errorData = await response.json();
          $(window).trigger("danbooru:error", "Error: " + (errorData.message || "Unknown error"));
        } catch (_error) {
          $(window).trigger("danbooru:error", "Error: " + (response.status + " " + response.statusText));
        }
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      try {
        const data = await response.json();
        return data;
      } catch (error) {
        $(window).trigger("danbooru:error", "Error: " + error.message);
        console.error("Failed to parse response as JSON:", error);
        throw new Error("Failed to parse response as JSON: " + error.message);
      }
    }, (error) => {
      if (error instanceof TaskCancelled) return Promise.reject(error);
      console.error(error);
      $(window).trigger("danbooru:error", "Error: " + error.message);
      throw error;
    });
  }

  /**
   * Deletes a favorite for the specified post.
   * @param {number} post_id The ID of the post to unfavorite.
   * @returns {Promise<Response>} The response from the server.
   */
  static async destroy (post_id, delay = 1000) {
    if (!post_id) return Promise.reject(new Error("Post ID is required"));

    return TaskQueue.add(async () => {
      return fetch(`/favorites/${post_id}.json`, {
        method: "DELETE",
        headers: {
          "Content-Type": "application/json",
          "accept": "*/*;q=0.5,text/javascript",
        },
        credentials: "include",
        mode: "cors",
        body: JSON.stringify({
          post_id: post_id,
          authenticity_token: encodeURIComponent(User._authToken),
        }),
      });
    }, { name: `Post.favorite.${post_id}`, unique: true, delay: delay }).then(async (response) => {
      if (!response.ok) {
        console.log("Response not OK:", response.status, response.statusText);
        try {
          const errorData = await response.json();
          $(window).trigger("danbooru:error", "Error: " + (errorData.message || "Unknown error"));
        } catch (_error) {
          $(window).trigger("danbooru:error", "Error: " + (response.status + " " + response.statusText));
        }
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      try {
        const data = await response.json();
        return data;
      } catch (error) {
        $(window).trigger("danbooru:error", "Error: " + error.message);
        console.error("Failed to parse response as JSON:", error);
        throw new Error("Failed to parse response as JSON: " + error.message);
      }
    }, (error) => {
      if (error instanceof TaskCancelled) return Promise.reject(error);
      console.error(error);
      $(window).trigger("danbooru:error", "Error: " + error.message);
      throw error;
    });
  }
}


