import { beforeEach, describe, expect, it, vi } from "vitest";

const post = { update: vi.fn(), delete: vi.fn(), undelete: vi.fn() };
const approval = { create: vi.fn(), disapprove: vi.fn() };
const flag = { destroy: vi.fn() };
const toast = { notice: vi.fn(), create: vi.fn(() => ({ message: "", timeout: 0 })), dismiss: vi.fn() };
const page = { matches: vi.fn(() => false) };

vi.mock("@/models/Post", async (importOriginal) => ({ ...await importOriginal<object>(), default: post }));
vi.mock("@/models/PostApproval", () => ({ default: approval }));
vi.mock("@/models/PostFlag", () => ({ default: flag }));
vi.mock("@/utility/Toast", () => ({ default: toast }));
vi.mock("@/utility/Page", () => ({ default: page }));

const POST_ID = 42;
const THUMB = { id: POST_ID, flags: "", rating: "q", tags: "fox red" };

function thumb (id = POST_ID, { flags = "", classes = "" } = {}) {
  $("body").append(`<article class="thumbnail ${classes}" data-id="${id}" data-flags="${flags}" data-tags="old" data-rating="s"></article>`);
  return $(`article.thumbnail[data-id="${id}"]`).last();
}

async function load () {
  const BulkActions = (await import("@/pages/posts/BulkActions")).default;
  const PendingUpdates = (await import("@/pages/posts/PendingUpdates")).default;
  const reload = vi.spyOn(BulkActions as any, "reload").mockImplementation(() => {});
  return { BulkActions, PendingUpdates, reload };
}

async function apiError (status: number) {
  const { ApiError } = await import("@/utility/ApiRequest");
  return new ApiError(status, "nope");
}

describe("BulkActions", () => {
  beforeEach(() => {
    for (const group of [post, approval, flag])
      for (const fn of Object.values(group)) fn.mockReset().mockResolvedValue(undefined);
    post.update.mockResolvedValue(THUMB);
    toast.notice.mockReset();
    page.matches.mockReset().mockReturnValue(false);
  });

  describe("update", () => {
    it("passes nested params to the model and syncs the thumbnail", async () => {
      const $thumb = thumb();
      const { BulkActions, PendingUpdates } = await load();

      await BulkActions.update(POST_ID, { rating: "q" });

      expect(post.update).toHaveBeenCalledWith(POST_ID, { rating: "q" });
      expect($thumb.attr("data-tags")).toBe("fox red");
      expect($thumb.data("rating")).toBe("q");
      expect(PendingUpdates.count).toBe(0);
    });

    it("stays quiet on failure and balances the counter", async () => {
      post.update.mockRejectedValue(await apiError(422));
      const { BulkActions, PendingUpdates } = await load();

      await expect(BulkActions.update(POST_ID, { rating: "q" })).resolves.toBeUndefined();
      expect(toast.notice).not.toHaveBeenCalled();
      expect(PendingUpdates.count).toBe(0);
    });
  });

  describe("tagScript", () => {
    it("joins tag arrays and forwards the reason", async () => {
      const { BulkActions } = await load();

      await BulkActions.tagScript(POST_ID, ["a", "-b"], "cleanup");
      expect(post.update).toHaveBeenCalledWith(POST_ID, { tag_string_diff: "a -b", edit_reason: "cleanup" });

      await BulkActions.tagScript(POST_ID, "c");
      expect(post.update).toHaveBeenLastCalledWith(POST_ID, { tag_string_diff: "c", edit_reason: "" });
    });
  });

  describe("delete", () => {
    it("marks the thumbnail deleted with the default options", async () => {
      const $thumb = thumb(POST_ID, { flags: "pending", classes: "pending" });
      const { BulkActions, reload } = await load();

      await BulkActions.delete(POST_ID, "dupe");

      expect(post.delete).toHaveBeenCalledWith(POST_ID, { reason: "dupe", from_flag: false, move_favorites: false, dmail: null, dmail_title: null });
      expect(toast.notice).toHaveBeenCalledWith("Deleted post.");
      expect($thumb.attr("data-flags")).toBe("deleted");
      expect($thumb.data("flags")).toBe("deleted");
      expect($thumb.hasClass("deleted")).toBe(true);
      expect($thumb.hasClass("pending")).toBe(false);
      expect(reload).not.toHaveBeenCalled();
    });

    it("forwards the options and reloads when asked", async () => {
      const { BulkActions, reload } = await load();

      await BulkActions.delete(POST_ID, "", { reload: true, from_flag: true, move_favorites: true, dmail: "Body", dmail_title: "Title" });

      expect(post.delete).toHaveBeenCalledWith(POST_ID, { reason: "", from_flag: true, move_favorites: true, dmail: "Body", dmail_title: "Title" });
      expect(reload).toHaveBeenCalledOnce();
    });

    it("reloads a stale page on 409 and stays quiet otherwise", async () => {
      post.delete.mockRejectedValue(await apiError(409));
      const { BulkActions, PendingUpdates, reload } = await load();

      await BulkActions.delete(POST_ID, "dupe");
      expect(reload).toHaveBeenCalledOnce();

      post.delete.mockRejectedValue(await apiError(422));
      await BulkActions.delete(POST_ID, "dupe");
      expect(reload).toHaveBeenCalledOnce();
      expect(toast.notice).not.toHaveBeenCalled();
      expect(PendingUpdates.count).toBe(0);
    });
  });

  it("undeletes and clears the status flags", async () => {
    const $thumb = thumb(POST_ID, { flags: "deleted", classes: "deleted" });
    const { BulkActions } = await load();

    await BulkActions.undelete(POST_ID);

    expect(post.undelete).toHaveBeenCalledWith(POST_ID);
    expect($thumb.attr("data-flags")).toBe("");
    expect($thumb.hasClass("deleted")).toBe(false);
    expect(toast.notice).toHaveBeenCalledWith("Undeleted post.");
  });

  it("unflags without reloading", async () => {
    const $thumb = thumb(POST_ID, { flags: "pending flagged", classes: "pending flagged" });
    const { BulkActions, reload } = await load();

    await BulkActions.unflag(POST_ID);
    expect(flag.destroy).toHaveBeenCalledWith(POST_ID, "none");
    expect($thumb.attr("data-flags")).toBe("pending");
    expect($thumb.hasClass("flagged")).toBe(false);
    expect($thumb.hasClass("pending")).toBe(true);
    expect(toast.notice).toHaveBeenCalledWith("Unflagged post");
    expect(reload).not.toHaveBeenCalled();

    await BulkActions.unflag(POST_ID, "approve");
    expect(flag.destroy).toHaveBeenLastCalledWith(POST_ID, "approve");
  });

  describe("approve", () => {
    it("strips the pending flag from the thumbnail", async () => {
      const $thumb = thumb(POST_ID, { flags: "pending", classes: "pending" });
      const { BulkActions } = await load();

      await BulkActions.approve(POST_ID);

      expect(approval.create).toHaveBeenCalledWith(POST_ID);
      expect($thumb.attr("data-flags")).toBe("");
      expect($thumb.hasClass("pending")).toBe(false);
      expect(toast.notice).toHaveBeenCalledWith("Approved post #42");
    });

    it("is silent without a thumbnail on the page", async () => {
      const { BulkActions } = await load();

      await BulkActions.approve(POST_ID);

      expect(approval.create).toHaveBeenCalledWith(POST_ID);
      expect(toast.notice).not.toHaveBeenCalled();
    });
  });

  it("disapproves and reloads only on posts#show", async () => {
    const { BulkActions, reload } = await load();

    await BulkActions.disapprove(POST_ID, "borderline_quality", "m");
    expect(approval.disapprove).toHaveBeenCalledWith(POST_ID, "borderline_quality", "m");
    expect(reload).not.toHaveBeenCalled();

    page.matches.mockReturnValue(true);
    await BulkActions.disapprove(POST_ID, "borderline_quality");
    expect(page.matches).toHaveBeenCalledWith("posts", "show");
    expect(reload).toHaveBeenCalledOnce();
  });

  describe("syncThumbnail", () => {
    it("writes attributes, the jQuery data cache, and the status and rating classes", async () => {
      const $thumb = thumb(POST_ID, { classes: "rating-safe has-parent blacklistable" });
      $thumb.data("tags"); // prime the cache the way the mode menu does
      const { BulkActions } = await load();

      BulkActions.syncThumbnail({ ...THUMB, flags: "pending flagged" } as any);

      expect($thumb.attr("data-tags")).toBe("fox red");
      expect($thumb.data("tags")).toBe("fox red");
      expect($thumb.attr("data-rating")).toBe("q");
      expect($thumb.attr("data-flags")).toBe("pending flagged");
      expect($thumb.hasClass("pending")).toBe(true);
      expect($thumb.hasClass("flagged")).toBe(true);
      expect($thumb.hasClass("deleted")).toBe(false);
      expect($thumb.hasClass("rating-safe")).toBe(false);
      expect($thumb.hasClass("rating-questionable")).toBe(true);
      expect($thumb.hasClass("has-parent")).toBe(true);
      expect($thumb.hasClass("blacklistable")).toBe(true);
    });

    it("clears status classes for an active post and updates every matching thumbnail", async () => {
      const $a = thumb(POST_ID, { flags: "deleted", classes: "deleted" });
      const $b = thumb(POST_ID, { flags: "deleted", classes: "deleted" });
      const $other = thumb(7, { flags: "deleted", classes: "deleted" });
      const { BulkActions } = await load();

      const touched = BulkActions.syncThumbnail(THUMB as any);

      expect(touched.length).toBe(2);
      expect($a.hasClass("deleted")).toBe(false);
      expect($b.hasClass("deleted")).toBe(false);
      expect($other.hasClass("deleted")).toBe(true);
    });

    it("tolerates a post that is not on the page", async () => {
      const { BulkActions } = await load();
      expect(BulkActions.syncThumbnail(THUMB as any).length).toBe(0);
    });
  });
});
