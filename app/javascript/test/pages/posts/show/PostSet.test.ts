import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { htmlResponse, jsonResponse, setMeta } from "../../../helpers";

const { alertSpy, toast, createSpy } = vi.hoisted(() => {
  const toast = { message: "", timeout: 0, dismiss: vi.fn() };
  return { alertSpy: vi.fn(), toast, createSpy: vi.fn(() => toast) };
});

vi.mock("@/utility/Toast", () => ({
  default: { alert: (msg: string) => alertSpy(msg), create: (...args: unknown[]) => createSpy(...args), notice: vi.fn() },
}));
// The real queue sleeps between tasks; run them inline so the spec stays synchronous
vi.mock("@/utility/TaskQueue", () => ({ default: { add: (task: () => unknown) => Promise.resolve().then(task) } }));

async function load () {
  return (await import("@/pages/posts/show/PostSet")).default;
}

function requests (fetchSpy: ReturnType<typeof vi.spyOn>): { url: string; body: string }[] {
  return fetchSpy.mock.calls.map(([url, init]) => ({ url: String(url), body: String((init as RequestInit)?.body ?? "") }));
}

describe("PostSet", () => {
  beforeEach(() => {
    alertSpy.mockReset();
    createSpy.mockClear();
    toast.message = "";
    toast.timeout = 0;
    toast.dismiss.mockReset();
    setMeta("csrf-token", "tok");
  });

  describe("batching", () => {
    beforeEach(() => vi.useFakeTimers());
    afterEach(() => vi.useRealTimers());

    it("groups single-post calls per set and flushes one request per set after a second", async () => {
      const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({}));
      const PostSet = await load();

      PostSet.add_post(1, 10);
      PostSet.add_post(1, 11);
      PostSet.add_post("2", 12); // posts#index passes the select value as a string
      expect(toast.message).toBe("Updating posts (1 pending)");

      vi.advanceTimersByTime(999);
      expect(fetchSpy).not.toHaveBeenCalled();
      vi.advanceTimersByTime(1);
      await vi.runAllTicks();
      await Promise.resolve();

      expect(requests(fetchSpy)).toEqual([
        { url: "/post_sets/1/add_posts.json", body: "post_ids%5B%5D=10&post_ids%5B%5D=11" },
        { url: "/post_sets/2/add_posts.json", body: "post_ids%5B%5D=12" },
      ]);
    });

    it("keeps add and remove queues independent", async () => {
      const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({}));
      const PostSet = await load();

      PostSet.add_post(1, 10);
      PostSet.remove_post(1, 11);
      vi.advanceTimersByTime(1000);
      await Promise.resolve();
      await Promise.resolve();

      expect(requests(fetchSpy).map((r) => r.url).sort()).toEqual([
        "/post_sets/1/add_posts.json",
        "/post_sets/1/remove_posts.json",
      ]);
    });

    it("rejects a missing set id without queueing", async () => {
      const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({}));
      const PostSet = await load();
      PostSet.add_post(0, 10);
      PostSet.add_post("", 10);
      vi.advanceTimersByTime(1000);
      expect(alertSpy).toHaveBeenCalledTimes(2);
      expect(alertSpy).toHaveBeenCalledWith("Error: No set specified");
      expect(fetchSpy).not.toHaveBeenCalled();
    });
  });

  describe("add_many_posts / remove_many_posts", () => {
    it("reports success in the shared toast with a link to the set", async () => {
      vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({}));
      const PostSet = await load();

      await PostSet.add_many_posts(5, [1, 2]);
      expect(toast.message).toBe('Added 2 posts to <a href="/post_sets/5">set #5</a>');
      expect(toast.timeout).toBe(3);

      await PostSet.remove_many_posts(5, [1]);
      expect(toast.message).toBe('Removed post from <a href="/post_sets/5">set #5</a>');
    });

    it("alerts with the backend message and dismisses the pending toast on failure", async () => {
      vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ message: "Access denied" }, { status: 403 }));
      const PostSet = await load();

      PostSet.add_post(5, 1); // creates the pending toast
      await PostSet.add_many_posts(5, [1]);

      expect(alertSpy).toHaveBeenCalledWith("Error: Access denied");
      expect(toast.dismiss).toHaveBeenCalledWith(true);
    });

    it("falls back to the status line for a non-JSON failure", async () => {
      vi.spyOn(globalThis, "fetch").mockResolvedValue({ ...htmlResponse(500), statusText: "Internal Server Error" });
      const PostSet = await load();
      await PostSet.add_many_posts(5, [1]);
      expect(alertSpy).toHaveBeenCalledWith("Error: 500 Internal Server Error");
    });

    it("validates the set id before sending", async () => {
      const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({}));
      const PostSet = await load();
      await PostSet.add_many_posts(0, [1]);
      await PostSet.add_many_posts("5" as unknown as number, [1]);
      expect(alertSpy.mock.calls.map((c) => c[0])).toEqual(["Error: No set specified", "Error: Invalid set specified"]);
      expect(fetchSpy).not.toHaveBeenCalled();
    });
  });

  describe("populateSelect", () => {
    beforeEach(() => {
      document.body.innerHTML = '<select id="set-id"><option>stale</option></select>';
    });

    it("shows a loading placeholder, then grouped options with the remembered set selected", async () => {
      let resolve!: (value: unknown) => void;
      vi.spyOn(globalThis, "fetch").mockReturnValue(new Promise((r) => { resolve = r; }));
      localStorage.setItem("set", "8");
      const PostSet = await load();
      const select = $("#set-id") as JQuery<HTMLSelectElement>;

      const done = PostSet.populateSelect(select);
      expect(select.find("option").text()).toBe("Loading...");

      resolve(jsonResponse({ Owned: [["my set", 7], ["other set", 8]], Maintained: [] }));
      await done;

      expect(select.find("optgroup").map((_, g) => $(g).attr("label")).get()).toEqual(["Owned", "Maintained"]);
      expect(select.val()).toBe("8");
    });

    it("stores the chosen set as a number on change", async () => {
      vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ Owned: [["my set", 7]], Maintained: [] }));
      const PostSet = await load();
      await PostSet.populateSelect($("#set-id") as JQuery<HTMLSelectElement>);

      $("#set-id").val("7").trigger("change");
      const LStorage = (await import("@/utility/storage/Local")).default;
      expect(LStorage.Posts.Set).toBe(7);
    });

    it("alerts when the list cannot be loaded", async () => {
      vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ reason: "Access denied" }, { status: 403 }));
      const PostSet = await load();
      await PostSet.populateSelect($("#set-id") as JQuery<HTMLSelectElement>);
      expect(alertSpy).toHaveBeenCalledWith("Error getting sets list: Access denied");
    });
  });

  describe("bindRemoveLinks", () => {
    it("queues a removal with numeric ids from the link's data attributes", async () => {
      document.body.innerHTML = '<a href="#" class="set-nav-remove-link" data-set-id="3" data-post-id="44">x</a>';
      const PostSet = await load();
      const removeSpy = vi.spyOn(PostSet, "remove_post").mockImplementation(() => {});

      PostSet.bindRemoveLinks();
      document.querySelector<HTMLElement>("a.set-nav-remove-link")!.click();

      expect(removeSpy).toHaveBeenCalledWith(3, 44);
    });
  });
});
