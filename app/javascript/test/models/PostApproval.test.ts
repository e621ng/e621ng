import { afterEach, describe, expect, it } from "vitest";
import { bypassQueue, lastFetch, recordErrors, stubFetch } from "../apiHelpers";
import { jsonResponse } from "../helpers";

async function freshPostApproval () {
  return (await import("@/models/PostApproval")).default;
}

describe("PostApproval", () => {
  afterEach(() => { $(window).off("danbooru:error"); });

  describe("create", () => {
    it("POSTs the post id through the queue and resolves void on 201", async () => {
      const fetchSpy = stubFetch(jsonResponse({}, { status: 201 }));
      const queue = await bypassQueue();
      const PostApproval = await freshPostApproval();

      await expect(PostApproval.create(42)).resolves.toBeUndefined();

      const { url, init } = lastFetch(fetchSpy);
      expect(url).toBe("/staff/post/approval.json");
      expect(init.method).toBe("POST");
      expect(init.body).toBe(JSON.stringify({ post_id: 42 }));
      expect(queue.mock.calls[0][1]).toEqual({ name: "Post.approve" });
    });

    it("resolves on an empty 204 as well", async () => {
      stubFetch(jsonResponse(null, { status: 204 }));
      await bypassQueue();
      const PostApproval = await freshPostApproval();

      await expect(PostApproval.create(42)).resolves.toBeUndefined();
    });

    it("reports failures", async () => {
      stubFetch(jsonResponse({ success: false, message: "Access denied" }, { status: 403 }));
      await bypassQueue();
      const PostApproval = await freshPostApproval();
      const errors = recordErrors();

      await expect(PostApproval.create(42)).rejects.toMatchObject({ status: 403 });
      expect(errors).toEqual(["Error: Access denied"]);
    });
  });

  describe("destroy", () => {
    it("DELETEs the post id through the queue and resolves on 204", async () => {
      const fetchSpy = stubFetch(jsonResponse(null, { status: 204 }));
      const queue = await bypassQueue();
      const PostApproval = await freshPostApproval();

      await expect(PostApproval.destroy(42)).resolves.toBeUndefined();

      const { url, init } = lastFetch(fetchSpy);
      expect(url).toBe("/staff/post/approval.json");
      expect(init.method).toBe("DELETE");
      expect(init.body).toBe(JSON.stringify({ post_id: 42 }));
      expect(queue.mock.calls[0][1]).toEqual({ name: "Post.unapprove" });
    });
  });

  describe("disapprove", () => {
    it("POSTs the nested disapproval and resolves with the record", async () => {
      const record = { id: 1, post_id: 42, reason: "borderline_quality", message: "m" };
      const fetchSpy = stubFetch(jsonResponse(record));
      const queue = await bypassQueue();
      const PostApproval = await freshPostApproval();

      await expect(PostApproval.disapprove(42, "borderline_quality", "m")).resolves.toEqual(record);

      const { url, init } = lastFetch(fetchSpy);
      expect(url).toBe("/staff/post/disapprovals.json");
      expect(init.method).toBe("POST");
      expect(JSON.parse(init.body as string)).toEqual({ post_disapproval: { post_id: 42, reason: "borderline_quality", message: "m" } });
      expect(queue.mock.calls[0][1]).toEqual({ name: "Post.disapprove" });
    });

    it("reports failures", async () => {
      stubFetch(jsonResponse({ success: false, reason: "not found" }, { status: 404 }));
      await bypassQueue();
      const PostApproval = await freshPostApproval();
      const errors = recordErrors();

      await expect(PostApproval.disapprove(42, "x")).rejects.toMatchObject({ status: 404 });
      expect(errors).toEqual(["Error: not found"]);
    });
  });
});
