import { afterEach, describe, expect, it, vi } from "vitest";
import FavoriteFolder from "@/models/FavoriteFolder";

function mockFetch (status: number, body: unknown) {
  const ok = status >= 200 && status < 300;
  vi.stubGlobal("fetch", vi.fn().mockResolvedValue({
    ok,
    status,
    statusText: ok ? "OK" : "Unprocessable Content",
    json: () => Promise.resolve(body),
  }));
}

function lastRequestBody () {
  const [url, options] = (fetch as ReturnType<typeof vi.fn>).mock.calls[0];
  return { url, method: options.method, body: JSON.parse(options.body) };
}

describe("models/FavoriteFolder", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  describe(".create", () => {
    it("POSTs name and parent_id to /favorite_folders.json and resolves the created folder", async () => {
      mockFetch(200, { id: 1, name: "Memes", parent_id: 5 });
      const result = await FavoriteFolder.create("Memes", 5);

      const { url, method, body } = lastRequestBody();
      expect(url).toBe("/favorite_folders.json");
      expect(method).toBe("POST");
      expect(body).toMatchObject({ name: "Memes", parent_id: 5 });
      expect(body).toHaveProperty("authenticity_token");
      expect(result).toEqual({ id: 1, name: "Memes", parent_id: 5 });
    });

    it("sends null parent_id for a root-level folder", async () => {
      mockFetch(200, { id: 1, name: "Memes", parent_id: null });
      await FavoriteFolder.create("Memes", null);
      expect(lastRequestBody().body.parent_id).toBeNull();
    });
  });

  describe(".rename", () => {
    it("PATCHes name to /favorite_folders/:id.json and resolves the renamed folder", async () => {
      mockFetch(200, { id: 1, name: "New Name", parent_id: null });
      const result = await FavoriteFolder.rename(1, "New Name");

      const { url, method, body } = lastRequestBody();
      expect(url).toBe("/favorite_folders/1.json");
      expect(method).toBe("PATCH");
      expect(body).toMatchObject({ name: "New Name" });
      expect(result).toEqual({ id: 1, name: "New Name", parent_id: null });
    });
  });

  describe(".move", () => {
    it("POSTs parent_id to /favorite_folders/:id/move.json and resolves { id, parent_id }", async () => {
      mockFetch(200, { id: 9, parent_id: 3 });
      const result = await FavoriteFolder.move(9, 3);

      const { url, method, body } = lastRequestBody();
      expect(url).toBe("/favorite_folders/9/move.json");
      expect(method).toBe("POST");
      expect(body).toMatchObject({ parent_id: 3 });
      expect(body).toHaveProperty("authenticity_token");
      expect(result).toEqual({ id: 9, parent_id: 3 });
    });

    it("sends a null parent_id to move to root", async () => {
      mockFetch(200, { id: 9, parent_id: null });
      await FavoriteFolder.move(9, null);
      expect(lastRequestBody().body.parent_id).toBeNull();
    });
  });

  describe("errors", () => {
    it("create/rename rejection carries the backend message, for inline modal display", async () => {
      mockFetch(422, { message: "A folder with that name already exists here" });
      await expect(FavoriteFolder.create("Dup", null)).rejects.toThrow("A folder with that name already exists here");
    });

    it("move rejection dispatches danbooru:error", async () => {
      mockFetch(422, { message: "Cannot move a folder into itself" });
      const handler = vi.fn();
      $(window).on("danbooru:error", handler);

      await expect(FavoriteFolder.move(1, 2)).rejects.toThrow("Cannot move a folder into itself");
      expect(handler).toHaveBeenCalled();
      $(window).off("danbooru:error", handler);
    });

    it("falls back to status/statusText when the error body isn't JSON", async () => {
      vi.stubGlobal("fetch", vi.fn().mockResolvedValue({
        ok: false,
        status: 500,
        statusText: "Internal Server Error",
        json: () => Promise.reject(new Error("not JSON")),
      }));
      await expect(FavoriteFolder.rename(1, "X")).rejects.toThrow("500 Internal Server Error");
    });
  });
});
