import { afterEach, describe, expect, it } from "vitest";
import { bypassQueue, lastFetch, recordErrors, stubFetch } from "../apiHelpers";
import { jsonResponse } from "../helpers";

async function freshPostFlag () {
  return (await import("@/models/PostFlag")).default;
}

describe("PostFlag", () => {
  afterEach(() => { $(window).off("danbooru:error"); });

  describe("create", () => {
    it("POSTs the nested flag params through the queue", async () => {
      const flag = { id: 1, post_id: 42, reason_name: "inferior" };
      const fetchSpy = stubFetch(jsonResponse(flag, { status: 201 }));
      const queue = await bypassQueue();
      const PostFlag = await freshPostFlag();

      await expect(PostFlag.create(42, { reason_name: "inferior", parent_id: 7, note: "n" })).resolves.toEqual(flag);

      const { url, init } = lastFetch(fetchSpy);
      expect(url).toBe("/post_flags.json");
      expect(init.method).toBe("POST");
      expect(JSON.parse(init.body as string)).toEqual({ post_flag: { post_id: 42, reason_name: "inferior", parent_id: 7, note: "n" } });
      expect(queue.mock.calls[0][1]).toEqual({ name: "Post.flag" });
    });

    it("reports validation failures", async () => {
      stubFetch(jsonResponse({ errors: { post: ["is already flagged"] } }, { status: 422 }));
      await bypassQueue();
      const PostFlag = await freshPostFlag();
      const errors = recordErrors();

      await expect(PostFlag.create(42, { reason_name: "inferior" })).rejects.toMatchObject({ status: 422 });
      expect(errors).toEqual(["Error: is already flagged"]);
    });
  });

  describe("destroy", () => {
    it("DELETEs with the default approval and resolves on 204", async () => {
      const fetchSpy = stubFetch(jsonResponse(null, { status: 204 }));
      const queue = await bypassQueue();
      const PostFlag = await freshPostFlag();

      await expect(PostFlag.destroy(42)).resolves.toBeUndefined();

      const { url, init } = lastFetch(fetchSpy);
      expect(url).toBe("/posts/42/flag.json");
      expect(init.method).toBe("DELETE");
      expect(init.body).toBe(JSON.stringify({ approval: "none" }));
      expect(queue.mock.calls[0][1]).toEqual({ name: "Post.unflag" });
    });

    it("forwards an explicit approval", async () => {
      const fetchSpy = stubFetch(jsonResponse(null, { status: 204 }));
      await bypassQueue();
      const PostFlag = await freshPostFlag();

      await PostFlag.destroy(42, "approve");

      expect(lastFetch(fetchSpy).init.body).toBe(JSON.stringify({ approval: "approve" }));
    });

    it("reports failures", async () => {
      stubFetch(jsonResponse({ success: false, message: "Access denied" }, { status: 403 }));
      await bypassQueue();
      const PostFlag = await freshPostFlag();
      const errors = recordErrors();

      await expect(PostFlag.destroy(42)).rejects.toMatchObject({ status: 403 });
      expect(errors).toEqual(["Error: Access denied"]);
    });
  });
});
