import CurrentUser from "@/models/CurrentUser";

export interface FavoriteFolderRecord {
  id: number;
  name: string;
  parent_id: number | null;
}

// POST /favorite_folders/:id/move.json returns only { id, parent_id } - no name.
export interface FavoriteFolderMoveResult {
  id: number;
  parent_id: number | null;
}

/**
 * Thin client for the folder create/rename/move endpoints. create/rename don't dispatch
 * `danbooru:error` on failure - the create/rename overlay shows the error inline instead,
 * so the caller catches the rejection itself. move() dispatches it, like Favorite.move,
 * since a failed drag has no inline UI to show the error in.
 */
export default class FavoriteFolder {
  static create (name: string, parentId: string | number | null): Promise<FavoriteFolderRecord> {
    return FavoriteFolder.submit("/favorite_folders.json", "POST", { name, parent_id: parentId || null });
  }

  static rename (id: string | number, name: string): Promise<FavoriteFolderRecord> {
    return FavoriteFolder.submit(`/favorite_folders/${id}.json`, "PATCH", { name });
  }

  static async move (folderId: number, parentId: number | null): Promise<FavoriteFolderMoveResult> {
    const response = await fetch(`/favorite_folders/${folderId}/move.json`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "accept": "*/*;q=0.5,text/javascript",
      },
      credentials: "include",
      mode: "cors",
      body: JSON.stringify({ parent_id: parentId, authenticity_token: CurrentUser.encodedAuthToken }),
    });

    if (!response.ok) {
      let message = `${response.status} ${response.statusText}`;
      try {
        const errorData = await response.json();
        message = errorData.message || message;
      } catch (_error) {
        // Response body wasn't JSON - fall back to the status text already captured above.
      }
      $(window).trigger("danbooru:error", "Error: " + message);
      throw new Error(message);
    }

    return response.json();
  }

  private static async submit (url: string, method: string, body: Record<string, unknown>): Promise<FavoriteFolderRecord> {
    const response = await fetch(url, {
      method,
      headers: {
        "Content-Type": "application/json",
        "accept": "*/*;q=0.5,text/javascript",
      },
      credentials: "include",
      mode: "cors",
      body: JSON.stringify({ ...body, authenticity_token: CurrentUser.encodedAuthToken }),
    });

    if (!response.ok) {
      let message = `${response.status} ${response.statusText}`;
      try {
        const errorData = await response.json();
        message = errorData.message || message;
      } catch (_error) {
        // Response body wasn't JSON - fall back to the status text already captured above.
      }
      throw new Error(message);
    }

    return response.json();
  }
}
