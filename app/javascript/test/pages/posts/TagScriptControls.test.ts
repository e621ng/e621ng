import { beforeEach, describe, expect, it, vi } from "vitest";

const bulk = { applyTagDiff: vi.fn() };
const notice = { dismiss: vi.fn() };
const toast = { alert: vi.fn(), create: vi.fn(() => notice) };

vi.mock("@/pages/posts/BulkActions", () => ({ default: bulk }));
vi.mock("@/utility/Toast", async (importOriginal) => ({ ...await importOriginal<object>(), default: toast }));

const thumb = (id: number, tags: string, classes = "") => `<article class="thumbnail ${classes}" data-id="${id}" data-rating="s" data-tags="${tags}"></article>`;

function render ({ hidden = 0 } = {}) {
  const thumbs = [thumb(1, "wolf solo"), thumb(2, "fox"), thumb(3, "wolf", hidden ? "blacklisted" : "")];
  document.body.innerHTML = `
    <input id="tag-script-field">
    <button id="tag-script-all">All</button>
    <input id="tag-script-reason" value="cleanup">
    <div id="posts">${thumbs.join("")}</div>
    ${thumb(99, "wolf")}`;
}

async function load () {
  const TagScriptControls = (await import("@/pages/posts/TagScriptControls")).default;
  const LStorage = (await import("@/utility/storage/Local")).default;
  return { TagScriptControls: TagScriptControls.instance, LStorage };
}

const field = () => document.querySelector<HTMLInputElement>("#tag-script-field");

describe("TagScriptControls", () => {
  beforeEach(() => {
    render();
    bulk.applyTagDiff.mockReset();
    toast.alert.mockReset();
    toast.create.mockClear();
    notice.dismiss.mockReset();
  });

  it("saves the script on blur and flags invalid scripts", async () => {
    const { LStorage } = await load();

    field().value = "[if wolf canine]";
    field().dispatchEvent(new Event("blur"));

    expect(LStorage.Posts.TagScript.Content).toBe("[if wolf canine]");
    expect(toast.alert).toHaveBeenCalledWith("Invalid tag script command: [if wolf canine]");
  });

  describe("applyTo", () => {
    it("evaluates the script against the post's cached tags", async () => {
      const { TagScriptControls, LStorage } = await load();
      LStorage.Posts.TagScript.Content = "[if wolf, canine] -solo";

      TagScriptControls.applyTo(1);
      expect(bulk.applyTagDiff).toHaveBeenCalledWith(1, ["canine", "-solo"], "cleanup");

      TagScriptControls.applyTo(2);
      expect(bulk.applyTagDiff).toHaveBeenLastCalledWith(2, ["-solo"], "cleanup");
    });

    it("sends nothing when the script produces no changes", async () => {
      const { TagScriptControls, LStorage } = await load();
      LStorage.Posts.TagScript.Content = "[if wolf, canine]";

      TagScriptControls.applyTo(2);
      expect(bulk.applyTagDiff).not.toHaveBeenCalled();
    });

    it("alerts on an invalid script without sending anything", async () => {
      const { TagScriptControls, LStorage } = await load();
      LStorage.Posts.TagScript.Content = "[fi wolf, canine]";

      TagScriptControls.applyTo(1);
      expect(toast.alert).toHaveBeenCalled();
      expect(bulk.applyTagDiff).not.toHaveBeenCalled();
    });
  });

  describe("applyAll", () => {
    it("applies to every post in the gallery after confirming", async () => {
      const confirm = vi.spyOn(window, "confirm").mockReturnValue(true);
      const { LStorage } = await load();
      LStorage.Posts.TagScript.Content = "[if wolf, canine]";

      document.getElementById("tag-script-all").click();

      expect(confirm).toHaveBeenCalledWith("Apply the tag script to 3 posts?");
      expect(bulk.applyTagDiff.mock.calls.map((call) => call[0])).toEqual([1, 3]);
    });

    it("mentions blacklisted posts separately", async () => {
      render({ hidden: 1 });
      const confirm = vi.spyOn(window, "confirm").mockReturnValue(true);
      const { TagScriptControls, LStorage } = await load();
      LStorage.Posts.TagScript.Content = "canine";

      TagScriptControls.applyAll();

      expect(confirm).toHaveBeenCalledWith("Apply the tag script to 3 posts (1 of them hidden by your blacklist)?");
      expect(bulk.applyTagDiff).toHaveBeenCalledTimes(3);
    });

    it("does nothing when cancelled", async () => {
      vi.spyOn(window, "confirm").mockReturnValue(false);
      const { TagScriptControls, LStorage } = await load();
      LStorage.Posts.TagScript.Content = "canine";

      TagScriptControls.applyAll();
      expect(bulk.applyTagDiff).not.toHaveBeenCalled();
    });

    it("does not ask to confirm an invalid script", async () => {
      const confirm = vi.spyOn(window, "confirm");
      const { TagScriptControls, LStorage } = await load();
      LStorage.Posts.TagScript.Content = "[oops]";

      TagScriptControls.applyAll();
      expect(confirm).not.toHaveBeenCalled();
      expect(toast.alert).toHaveBeenCalled();
    });
  });

  describe("slots", () => {
    it("loads the slot into the field, announcing only when asked", async () => {
      const { TagScriptControls, LStorage } = await load();
      LStorage.Posts.TagScript.Content = "slot one";

      TagScriptControls.activate(false);
      expect(field().value).toBe("slot one");
      expect(toast.create).not.toHaveBeenCalled();

      TagScriptControls.activate(true);
      expect(toast.create).toHaveBeenCalledWith(expect.stringContaining("Switched to tag script #1"));
    });

    it("switches slots and replaces the previous notice", async () => {
      const { TagScriptControls, LStorage } = await load();
      LStorage.Posts.TagScript.ID = 2;
      LStorage.Posts.TagScript.Content = "slot two";
      LStorage.Posts.TagScript.ID = 1;

      TagScriptControls.switchSlot(2);
      expect(LStorage.Posts.TagScript.ID).toBe(2);
      expect(field().value).toBe("slot two");

      TagScriptControls.switchSlot(3);
      expect(notice.dismiss).toHaveBeenCalledWith(true);
      expect(toast.create).toHaveBeenCalledTimes(2);
    });

    it("ignores the current slot", async () => {
      const { TagScriptControls } = await load();
      TagScriptControls.switchSlot(1);
      expect(toast.create).not.toHaveBeenCalled();
    });
  });
});
