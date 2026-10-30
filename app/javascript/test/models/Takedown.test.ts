import { afterEach, describe, expect, it } from "vitest";
import { bypassQueue, lastFetch, recordErrors, stubFetch } from "../apiHelpers";
import { jsonResponse } from "../helpers";

async function freshTakedown () {
  return (await import("@/models/Takedown")).default;
}

describe("Takedown", () => {
  afterEach(() => { $(window).off("danbooru:error"); });

  it("countMatchingPosts POSTs the tags and resolves with the count", async () => {
    const fetchSpy = stubFetch(jsonResponse({ matched_post_count: 12 }));
    const queue = await bypassQueue();
    const Takedown = await freshTakedown();

    await expect(Takedown.countMatchingPosts("foo bar")).resolves.toBe(12);

    const { url, init } = lastFetch(fetchSpy);
    expect(url).toBe("/takedowns/count_matching_posts.json");
    expect(init.method).toBe("POST");
    expect(JSON.parse(init.body as string)).toEqual({ post_tags: "foo bar" });
    expect(queue.mock.calls[0][1]).toEqual({ name: "Takedown.countMatchingPosts" });
  });

  it("addPostsByTags POSTs to the member route and resolves with the added ids", async () => {
    const body = { added_count: 2, added_post_ids: [1, 2] };
    const fetchSpy = stubFetch(jsonResponse(body));
    await bypassQueue();
    const Takedown = await freshTakedown();

    await expect(Takedown.addPostsByTags(5, "foo")).resolves.toEqual(body);

    const { url, init } = lastFetch(fetchSpy);
    expect(url).toBe("/takedowns/5/add_by_tags.json");
    expect(JSON.parse(init.body as string)).toEqual({ post_tags: "foo" });
  });

  it("addPostsByIds sends the raw id string for the server to parse", async () => {
    const fetchSpy = stubFetch(jsonResponse({ added_count: 0, added_post_ids: [] }));
    await bypassQueue();
    const Takedown = await freshTakedown();

    await Takedown.addPostsByIds(5, "1 2 https://e621.net/posts/3");

    const { url, init } = lastFetch(fetchSpy);
    expect(url).toBe("/takedowns/5/add_by_ids.json");
    expect(JSON.parse(init.body as string)).toEqual({ post_ids: "1 2 https://e621.net/posts/3" });
  });

  it("removePost resolves on 204 with the id as a string", async () => {
    const fetchSpy = stubFetch(jsonResponse(null, { status: 204 }));
    await bypassQueue();
    const Takedown = await freshTakedown();

    await expect(Takedown.removePost(5, 42)).resolves.toBeUndefined();

    const { url, init } = lastFetch(fetchSpy);
    expect(url).toBe("/takedowns/5/remove_by_ids.json");
    expect(JSON.parse(init.body as string)).toEqual({ post_ids: "42" });
  });

  it("reports and rejects failures", async () => {
    stubFetch(jsonResponse({ message: "Access Denied" }, { status: 403 }));
    await bypassQueue();
    const Takedown = await freshTakedown();
    const errors = recordErrors();

    await expect(Takedown.addPostsByIds(5, "1")).rejects.toMatchObject({ status: 403 });
    expect(errors).toEqual(["Error: Access Denied"]);
  });
});
