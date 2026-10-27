import { afterEach, describe, expect, it, vi } from "vitest";
import { bypassQueue, lastFetch, recordErrors, stubFetch } from "../apiHelpers";
import { htmlResponse, jsonResponse } from "../helpers";

const POST = { id: 42, tag_string: "a b" };
const THUMB = { id: 42, flags: "", rating: "q", tags: "a b" };

async function freshPost () {
  return (await import("@/models/Post")).default;
}

describe("Post", () => {
  afterEach(() => { $(window).off("danbooru:error"); });

  describe("update", () => {
    it("PUTs the nested post params through the queue", async () => {
      const fetchSpy = stubFetch(jsonResponse(THUMB));
      const queue = await bypassQueue();
      const Post = await freshPost();

      await expect(Post.update(42, { rating: "q" })).resolves.toEqual(THUMB);

      const { url, init } = lastFetch(fetchSpy);
      expect(url).toBe("/posts/42.json?v2=true&mode=thumbnails");
      expect(init.method).toBe("PUT");
      expect(init.body).toBe(JSON.stringify({ post: { rating: "q" } }));
      expect(queue.mock.calls[0][1]).toEqual({ name: "Post.update" });
    });

    it("reports failures with a link to the post", async () => {
      stubFetch(jsonResponse({ errors: { tag_string: ["is invalid"] } }, { status: 422 }));
      await bypassQueue();
      const Post = await freshPost();
      const errors = recordErrors();

      await expect(Post.update(42, { tag_string: "x" })).rejects.toMatchObject({ status: 422 });
      expect(errors).toEqual(['There was an error updating <a href="/posts/42">post #42</a>: is invalid']);
    });

    it("passes a cancelled task through", async () => {
      stubFetch(jsonResponse(THUMB));
      const { default: TaskQueue, TaskCancelled } = await import("@/utility/TaskQueue");
      vi.spyOn(TaskQueue, "add").mockImplementation(() => Promise.reject(new TaskCancelled("Replaced")));
      const Post = await freshPost();
      const errors = recordErrors();

      await expect(Post.update(42, { rating: "q" })).rejects.toBeInstanceOf(TaskCancelled);
      expect(errors).toEqual([]);
    });
  });

  describe("delete", () => {
    it("POSTs the deletion form as JSON booleans and nulls", async () => {
      const fetchSpy = stubFetch(jsonResponse(POST, { status: 201 }));
      const queue = await bypassQueue();
      const Post = await freshPost();

      await expect(Post.delete(42, { reason: "dupe" })).resolves.toEqual(POST);

      const { url, init } = lastFetch(fetchSpy);
      expect(url).toBe("/staff/post/posts/42/delete.json");
      expect(init.method).toBe("POST");
      expect(JSON.parse(init.body as string)).toEqual({
        commit: "Delete", reason: "dupe", from_flag: false, move_favorites: false, dmail: null, dmail_title: null,
      });
      expect(queue.mock.calls[0][1]).toEqual({ name: "Post.delete_with_reason" });
    });

    it("forwards the optional fields", async () => {
      const fetchSpy = stubFetch(jsonResponse(POST, { status: 201 }));
      await bypassQueue();
      const Post = await freshPost();

      await Post.delete(42, { reason: "", from_flag: true, move_favorites: true, dmail: "Body", dmail_title: "Title" });

      expect(JSON.parse(lastFetch(fetchSpy).init.body as string)).toEqual({
        commit: "Delete", reason: "", from_flag: true, move_favorites: true, dmail: "Body", dmail_title: "Title",
      });
    });

    it("rejects with status 409 when the post is already deleted", async () => {
      stubFetch(jsonResponse({ reason: "Post #42 is already deleted" }, { status: 409 }));
      await bypassQueue();
      const Post = await freshPost();
      const errors = recordErrors();

      await expect(Post.delete(42, { reason: "dupe" })).rejects.toMatchObject({ status: 409 });
      expect(errors).toEqual(["Error: Post #42 is already deleted"]);
    });

    it("rejects without crashing when the backend redirects to an HTML page", async () => {
      stubFetch(htmlResponse(200));
      await bypassQueue();
      const Post = await freshPost();
      const errors = recordErrors();

      await expect(Post.delete(42, { reason: "" })).rejects.toBeInstanceOf(SyntaxError);
      expect(errors).toHaveLength(1);
    });
  });

  describe("undelete", () => {
    it("POSTs through the queue", async () => {
      const fetchSpy = stubFetch(jsonResponse(POST, { status: 201 }));
      const queue = await bypassQueue();
      const Post = await freshPost();

      await expect(Post.undelete(42)).resolves.toEqual(POST);

      const { url, init } = lastFetch(fetchSpy);
      expect(url).toBe("/staff/post/posts/42/undelete.json");
      expect(init.method).toBe("POST");
      expect(init.body).toBeUndefined();
      expect(queue.mock.calls[0][1]).toEqual({ name: "Post.undelete" });
    });
  });

  describe.each([
    ["expunge", (Post: any) => Post.expunge(42, "illegal"), "/staff/post/posts/42/expunge.json", { reason: "illegal" }],
    ["regenerateImageSamples", (Post: any) => Post.regenerateImageSamples(42), "/staff/post/posts/42/regenerate_thumbnails.json", undefined],
    ["regenerateVideoSamples", (Post: any) => Post.regenerateVideoSamples(42), "/staff/post/posts/42/regenerate_videos.json", undefined],
  ])("%s", (_name, call, expectedUrl, expectedBody) => {
    it("POSTs directly without the queue", async () => {
      const fetchSpy = stubFetch(jsonResponse(POST, { status: 201 }));
      const queue = await bypassQueue();
      const Post = await freshPost();

      await expect(call(Post)).resolves.toEqual(POST);

      const { url, init } = lastFetch(fetchSpy);
      expect(url).toBe(expectedUrl);
      expect(init.method).toBe("POST");
      expect(init.body).toBe(expectedBody === undefined ? undefined : JSON.stringify(expectedBody));
      expect(queue).not.toHaveBeenCalled();
    });

    it("reports backend failures", async () => {
      stubFetch(jsonResponse({ success: false, message: "Access denied" }, { status: 403 }));
      const Post = await freshPost();
      const errors = recordErrors();

      await expect(call(Post)).rejects.toMatchObject({ status: 403 });
      expect(errors).toEqual(["Error: Access denied"]);
    });
  });

  describe("copyNotes", () => {
    it("PUTs the destination and resolves on 204", async () => {
      const fetchSpy = stubFetch(jsonResponse(null, { status: 204 }));
      const queue = await bypassQueue();
      const Post = await freshPost();

      await expect(Post.copyNotes(42, 7)).resolves.toBeUndefined();

      const { url, init } = lastFetch(fetchSpy);
      expect(url).toBe("/posts/42/copy_notes.json");
      expect(init.method).toBe("PUT");
      expect(init.body).toBe(JSON.stringify({ other_post_id: 7 }));
      expect(queue).not.toHaveBeenCalled();
    });

    it("names an invalid destination on 404", async () => {
      stubFetch(jsonResponse({ success: false, reason: "not found" }, { status: 404 }));
      const Post = await freshPost();
      const errors = recordErrors();

      await expect(Post.copyNotes(42, 7)).rejects.toMatchObject({ status: 404 });
      expect(errors).toEqual(["Error: Invalid destination post"]);
    });

    it("reports the backend reason on other failures", async () => {
      stubFetch(jsonResponse({ success: false, reason: "Cannot copy notes to itself" }, { status: 400 }));
      const Post = await freshPost();
      const errors = recordErrors();

      await expect(Post.copyNotes(42, 42)).rejects.toMatchObject({ status: 400 });
      expect(errors).toEqual(["Error: Cannot copy notes to itself"]);
    });
  });
});
