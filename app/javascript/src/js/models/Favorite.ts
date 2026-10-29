import HTTP from "@/utility/HTTP";
import TaskQueue, { TaskCancelled } from "@/utility/TaskQueue";

export default class Favorite {

  /**
   * Creates a new favorite for the specified post.
   * @param post_id The ID of the post to favorite.
   * @param delay Minimum delay before the request is sent, in milliseconds.
   * @returns The parsed response from the server.
   */
  static create (post_id: number, delay: number = 1000): Promise<FavoriteResponse> {
    return Favorite.request(post_id, delay, "POST", "/favorites.json");
  }

  /**
   * Deletes a favorite for the specified post.
   * @param post_id The ID of the post to unfavorite.
   * @param delay Minimum delay before the request is sent, in milliseconds.
   * @returns The parsed response from the server.
   */
  static destroy (post_id: number, delay: number = 1000): Promise<FavoriteResponse> {
    return Favorite.request(post_id, delay, "DELETE", `/favorites/${post_id}.json`);
  }

  private static request (post_id: number, delay: number, method: string, url: string): Promise<FavoriteResponse> {
    // Create and destroy share a queue name on purpose: the latest request wins
    return TaskQueue.add(() => {
      return HTTP.request(url, {
        method,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ post_id }),
      });
    }, { name: `Post.favorite.${post_id}`, unique: true, delay }).then(async (response) => {
      if (!response.ok) {
        const error = new FavoriteError(response.status, await HTTP.errorMessage(response));
        if (!error.alreadyFavorited)
          $(window).trigger("danbooru:error", "Error: " + error.message);
        throw error;
      }

      try {
        return await response.json();
      } catch (error) {
        $(window).trigger("danbooru:error", "Error: " + error.message);
        console.error("Failed to parse response as JSON:", error);
        throw error;
      }
    }, (error) => {
      if (error instanceof TaskCancelled) return Promise.reject(error);
      console.error(error);
      $(window).trigger("danbooru:error", "Error: " + error.message);
      throw error;
    });
  }
}

export interface FavoriteResponse {
  post_id: number,
  favorite_count: number,
}

/** A non-2xx response from the favorites endpoints. `message` is the backend's error text. */
export class FavoriteError extends Error {
  public status: number;

  // NOTE: CurrentPost.favorite() relies on this flag to reconcile the page's favorite state.
  // The message is the exact string raised by FavoriteManager.add!.
  public alreadyFavorited: boolean;

  constructor (status: number, message: string) {
    super(message);
    this.name = "FavoriteError";
    this.status = status;
    this.alreadyFavorited = message === "You have already favorited this post";
  }
}
