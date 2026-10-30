import { beforeEach, describe, expect, it, vi } from "vitest";
import { tick } from "../../helpers";

const { api, trackDone } = vi.hoisted(() => ({
  api: {
    countMatchingPosts: vi.fn(),
    addPostsByTags: vi.fn(),
    addPostsByIds: vi.fn(),
    removePost: vi.fn(),
    clearPosts: vi.fn(),
  },
  trackDone: vi.fn(),
}));

vi.mock("@/models/Takedown", () => ({ default: api }));
vi.mock("@/utility/Toast", () => ({
  default: {
    // Same contract as ToastManager.track: resolves undefined on rejection
    track: async (promise: Promise<unknown>, _pending: string, done: (result: unknown) => string) => {
      try {
        const result = await promise;
        trackDone(done(result));
        return result;
      } catch {
        return undefined;
      }
    },
  },
}));

// Mirrors _editor_post.html.erb
function row (id: number | null, remove = false, statusClass: string | null = "keep"): string {
  const action = remove ? "delete" : "keep";
  const pid = id ?? "";
  return `
    <div id="takedown-post-${pid}" data-post-id="${pid}" class="takedown-post">
      <button type="button" class="st-button danger takedown-post-remove">
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" name="times"><path d="M18 6 6 18"></path><path d="m6 6 12 12"></path></svg>
      </button>
      <label for="takedown_posts_${pid}" class="takedown-post-label takedown-post-${action}">
        <input type="hidden" name="takedown_posts[${pid}]" value="0">
        <input type="checkbox" id="takedown_posts_${pid}" name="takedown_posts[${pid}]" value="1"${remove ? " checked" : ""}>
        <span class="takedown-post-action">${remove ? "Delete" : "Keep"}</span>
      </label>
      <span class="takedown-post-status${statusClass ? ` takedown-post-${statusClass}` : ""}"><a href="${id ? `/posts/${id}` : "#"}">post #${pid}</a></span>
    </div>`;
}

function mount (rows: string, { status = true } = {}): void {
  document.body.innerHTML = `
    <form>
      <div id="takedown-posts" data-takedown-id="5">
        <input type="checkbox" id="process_takedown" checked>
        <button type="button" id="takedown-keepall">Keep all</button>
        <button type="button" id="takedown-deleteall">Delete all</button>
        <div id="takedown-post-buttons">${rows}</div>
        <template id="takedown-post-template">${row(null)}</template>
        <input id="takedown-add-posts-tags">
        <button type="button" id="takedown-add-posts-tags-preview" disabled>Add</button>
        <button type="button" id="takedown-add-posts-tags-confirm" hidden>Confirm</button>
        <button type="button" id="takedown-add-posts-tags-cancel" hidden>Cancel</button>
        <div id="takedown-add-posts-tags-warning" hidden></div>
        <input id="takedown-add-posts-ids">
        <button type="button" id="takedown-add-posts-ids-submit" disabled>Add</button>
        <button type="button" id="takedown-clear-posts">Clear all posts</button>
      </div>
      ${status ? "<span id=\"post-status-select\"></span>" : ""}
    </form>`;
}

async function boot () {
  const TakedownEditor = (await import("@/pages/takedowns/TakedownEditor")).default;
  return TakedownEditor.instance;
}

const $id = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;
const statusText = () => $id("post-status-select").textContent;
const label = (id: number) => document.querySelector<HTMLLabelElement>(`label[for="takedown_posts_${id}"]`);
const checkbox = (id: number) => $id<HTMLInputElement>(`takedown_posts_${id}`);

function toggle (input: HTMLInputElement, checked: boolean): void {
  input.checked = checked;
  input.dispatchEvent(new Event("change", { bubbles: true }));
}

function type (input: HTMLInputElement, value: string): void {
  input.value = value;
  input.dispatchEvent(new Event("input", { bubbles: true }));
}

function pressEnter (input: HTMLElement): KeyboardEvent {
  const event = new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true });
  input.dispatchEvent(event);
  return event;
}

describe("TakedownEditor", () => {
  beforeEach(() => {
    for (const fn of Object.values(api)) fn.mockReset();
    trackDone.mockReset();
  });

  it("does nothing without the editor", async () => {
    document.body.innerHTML = "<span id=\"post-status-select\"></span>";
    await boot();
    expect(statusText()).toBe("");
  });

  describe("status hint", () => {
    it.each([
      ["Approved", [true, true]],
      ["Denied", [false, false]],
      ["Partially Approved", [true, false]],
    ])("reads %s on load", async (expected, states) => {
      mount(states.map((remove, i) => row(i + 1, remove)).join(""));
      await boot();
      expect(statusText()).toBe(`Status will be set to ${expected}`);
    });

    it("is empty when the list is empty", async () => {
      mount("");
      await boot();
      expect(statusText()).toBe("");
    });

    it("is empty when the takedown won't be processed", async () => {
      mount(row(1));
      await boot();
      toggle($id("process_takedown"), false);
      expect(statusText()).toBe("");
      toggle($id("process_takedown"), true);
      expect(statusText()).toBe("Status will be set to Denied");
    });

    it("tolerates the status span being absent", async () => {
      mount(row(1), { status: false });
      await boot();
      toggle(checkbox(1), true);
      expect(label(1).classList).toContain("takedown-post-delete");
    });
  });

  describe("keep / delete", () => {
    it("syncs the label and hint when a checkbox changes", async () => {
      mount(row(1) + row(2));
      await boot();

      toggle(checkbox(1), true);
      expect(label(1).className).toBe("takedown-post-label takedown-post-delete");
      expect(label(1).querySelector("span").textContent).toBe("Delete");
      expect(statusText()).toBe("Status will be set to Partially Approved");

      toggle(checkbox(1), false);
      expect(label(1).className).toBe("takedown-post-label takedown-post-keep");
      expect(label(1).querySelector("span").textContent).toBe("Keep");
      expect(statusText()).toBe("Status will be set to Denied");
    });

    it("Delete all / Keep all flip every row", async () => {
      mount(row(1) + row(2, true));
      await boot();

      $id("takedown-deleteall").click();
      expect([checkbox(1).checked, checkbox(2).checked]).toEqual([true, true]);
      expect(label(1).classList).toContain("takedown-post-delete");
      expect(statusText()).toBe("Status will be set to Approved");

      $id("takedown-keepall").click();
      expect([checkbox(1).checked, checkbox(2).checked]).toEqual([false, false]);
      expect(label(2).querySelector("span").textContent).toBe("Keep");
      expect(statusText()).toBe("Status will be set to Denied");
    });

    it("does not submit the form", async () => {
      api.removePost.mockResolvedValue(undefined);
      mount(row(1));
      await boot();
      const submit = vi.fn((event: Event) => event.preventDefault());
      document.querySelector("form").addEventListener("submit", submit);

      $id("takedown-deleteall").click();
      document.querySelector<HTMLElement>(".takedown-post-remove").click();
      $id("takedown-add-posts-ids-submit").click();
      await tick();
      expect(submit).not.toHaveBeenCalled();
    });
  });

  describe("removing a post", () => {
    it("removes the row and refreshes the hint once the request succeeds", async () => {
      api.removePost.mockResolvedValue(undefined);
      mount(row(1, true) + row(2));
      await boot();

      document.querySelector<HTMLElement>("#takedown-post-2 .takedown-post-remove").click();
      await tick();

      expect(api.removePost).toHaveBeenCalledWith(5, 2);
      expect($id("takedown-post-2")).toBeNull();
      expect(trackDone).toHaveBeenCalledWith("Post #2 removed from takedown");
      expect(statusText()).toBe("Status will be set to Approved");
    });

    it("keeps the row and re-enables the button on failure", async () => {
      api.removePost.mockRejectedValue(new Error("nope"));
      mount(row(1));
      await boot();

      const button = document.querySelector<HTMLButtonElement>(".takedown-post-remove");
      button.click();
      expect(button.disabled).toBe(true);
      button.click(); // ignored while in flight
      await tick();

      expect(api.removePost).toHaveBeenCalledTimes(1);
      expect($id("takedown-post-1")).not.toBeNull();
      expect(button.disabled).toBe(false);
    });
  });

  describe("adding by IDs", () => {
    it("enables the button from input events, including pastes", async () => {
      mount("");
      await boot();
      const input = $id<HTMLInputElement>("takedown-add-posts-ids");
      const button = $id<HTMLButtonElement>("takedown-add-posts-ids-submit");

      type(input, "12");
      expect(button.disabled).toBe(false);
      type(input, "   ");
      expect(button.disabled).toBe(true);
    });

    it("appends template rows for the added posts, skipping ones already listed", async () => {
      api.addPostsByIds.mockResolvedValue({ added_count: 2, added_post_ids: [1, 7] });
      mount(row(1, true));
      await boot();

      type($id<HTMLInputElement>("takedown-add-posts-ids"), "1 7");
      $id("takedown-add-posts-ids-submit").click();
      await tick();

      expect(api.addPostsByIds).toHaveBeenCalledWith(5, "1 7");
      expect(document.querySelectorAll(".takedown-post")).toHaveLength(2);

      const added = $id("takedown-post-7");
      expect(added.dataset.postId).toBe("7");
      expect(label(7).classList).toContain("takedown-post-keep");
      expect(checkbox(7).name).toBe("takedown_posts[7]");
      expect(added.querySelector<HTMLInputElement>("input[type=hidden]").name).toBe("takedown_posts[7]");
      expect(added.querySelector("a").getAttribute("href")).toBe("/posts/7");
      expect(added.querySelector("a").textContent).toBe("post #7");
      expect(added.querySelector(".takedown-post-status").classList).toContain("takedown-post-keep");

      expect(trackDone).toHaveBeenCalledWith("2 posts added to takedown");
      expect($id<HTMLInputElement>("takedown-add-posts-ids").value).toBe("");
      expect($id<HTMLButtonElement>("takedown-add-posts-ids-submit").disabled).toBe(true);
      expect(statusText()).toBe("Status will be set to Partially Approved");

      toggle(checkbox(7), true);
      expect(statusText()).toBe("Status will be set to Approved");
    });

    it("keeps the input on failure", async () => {
      api.addPostsByIds.mockRejectedValue(new Error("nope"));
      mount("");
      await boot();

      type($id<HTMLInputElement>("takedown-add-posts-ids"), "7");
      $id("takedown-add-posts-ids-submit").click();
      await tick();

      expect($id<HTMLInputElement>("takedown-add-posts-ids").value).toBe("7");
      expect($id<HTMLButtonElement>("takedown-add-posts-ids-submit").disabled).toBe(false);
      expect(document.querySelectorAll(".takedown-post")).toHaveLength(0);
    });

    it("Enter clicks the button only when it's enabled, and never submits", async () => {
      api.addPostsByIds.mockResolvedValue({ added_count: 0, added_post_ids: [] });
      mount("");
      await boot();
      const input = $id<HTMLInputElement>("takedown-add-posts-ids");

      expect(pressEnter(input).defaultPrevented).toBe(true);
      expect(api.addPostsByIds).not.toHaveBeenCalled();

      type(input, "3");
      pressEnter(input);
      expect(api.addPostsByIds).toHaveBeenCalledWith(5, "3");
    });
  });

  describe("adding by tags", () => {
    const input = () => $id<HTMLInputElement>("takedown-add-posts-tags");
    const warning = () => $id("takedown-add-posts-tags-warning");
    const visible = (id: string) => !$id(id).hidden;

    async function preview (tags: string, count: number) {
      api.countMatchingPosts.mockResolvedValue(count);
      type(input(), tags);
      $id("takedown-add-posts-tags-preview").click();
      await tick();
    }

    it("previews the count with escaped text and an encoded link", async () => {
      mount("");
      await boot();
      await preview("<b>x</b> & y", 3);

      expect(api.countMatchingPosts).toHaveBeenCalledWith("<b>x</b> & y");
      expect(warning().querySelector("b")).toBeNull();
      expect(warning().textContent).toBe("3 posts match the search '<b>x</b> & y'. Click Confirm to add them to the takedown.");

      const links = warning().querySelectorAll("a");
      expect(links).toHaveLength(2);
      const url = new URL(links[0].href, "http://localhost");
      expect(url.pathname).toBe("/posts");
      expect(url.searchParams.get("tags")).toBe("<b>x</b> & y -status:deleted");

      expect(input().disabled).toBe(true);
      expect(visible("takedown-add-posts-tags-preview")).toBe(false);
      expect(visible("takedown-add-posts-tags-confirm")).toBe(true);
      expect(visible("takedown-add-posts-tags-cancel")).toBe(true);
      expect(visible("takedown-add-posts-tags-warning")).toBe(true);
    });

    it("uses singular wording and notes the add limit", async () => {
      mount("");
      await boot();
      await preview("a", 1);
      expect(warning().textContent).toBe("1 post matches the search 'a'. Click Confirm to add it to the takedown.");

      $id("takedown-add-posts-tags-cancel").click();
      await preview("b", 1500);
      expect(warning().textContent).toMatch(/Only the first 1000 will be added\.$/);
    });

    it("cancel returns to the idle state", async () => {
      mount("");
      await boot();
      await preview("a", 2);

      $id("takedown-add-posts-tags-cancel").click();
      expect(input().value).toBe("");
      expect(input().disabled).toBe(false);
      expect(warning().hidden).toBe(true);
      expect(warning().childNodes).toHaveLength(0);
      expect(visible("takedown-add-posts-tags-preview")).toBe(true);
      expect($id<HTMLButtonElement>("takedown-add-posts-tags-preview").disabled).toBe(true);
      expect(visible("takedown-add-posts-tags-confirm")).toBe(false);
    });

    it("stays idle when the preview fails", async () => {
      api.countMatchingPosts.mockRejectedValue(new Error("nope"));
      mount("");
      await boot();
      type(input(), "a");
      $id("takedown-add-posts-tags-preview").click();
      await tick();

      expect(input().disabled).toBe(false);
      expect($id<HTMLButtonElement>("takedown-add-posts-tags-preview").disabled).toBe(false);
      expect(visible("takedown-add-posts-tags-confirm")).toBe(false);
    });

    it("confirm adds the posts and resets", async () => {
      api.addPostsByTags.mockResolvedValue({ added_count: 1, added_post_ids: [9] });
      mount("");
      await boot();
      await preview("  a  ", 1);

      $id("takedown-add-posts-tags-confirm").click();
      await tick();

      expect(api.addPostsByTags).toHaveBeenCalledWith(5, "a");
      expect($id("takedown-post-9")).not.toBeNull();
      expect(trackDone).toHaveBeenCalledWith("1 post added to takedown");
      expect(input().value).toBe("");
      expect(visible("takedown-add-posts-tags-confirm")).toBe(false);
    });

    it("confirm failure stays in the preview state", async () => {
      api.addPostsByTags.mockRejectedValue(new Error("nope"));
      mount("");
      await boot();
      await preview("a", 1);

      $id("takedown-add-posts-tags-confirm").click();
      await tick();

      expect(input().value).toBe("a");
      expect(visible("takedown-add-posts-tags-confirm")).toBe(true);
      expect($id<HTMLButtonElement>("takedown-add-posts-tags-confirm").disabled).toBe(false);
    });

    it("Enter in the tags field previews", async () => {
      api.countMatchingPosts.mockResolvedValue(0);
      mount("");
      await boot();
      type(input(), "a");
      pressEnter(input());
      expect(api.countMatchingPosts).toHaveBeenCalledWith("a");
    });
  });
  describe("clearing all posts", () => {
    const button = () => $id<HTMLButtonElement>("takedown-clear-posts");

    it("does nothing when the confirmation is declined", async () => {
      const confirmSpy = vi.spyOn(window, "confirm").mockReturnValue(false);
      mount(row(1) + row(2, true));
      await boot();

      button().click();
      await tick();

      expect(confirmSpy).toHaveBeenCalledWith("Remove all 2 posts from this takedown? This cannot be undone.");
      expect(api.clearPosts).not.toHaveBeenCalled();
      expect(document.querySelectorAll(".takedown-post")).toHaveLength(2);
    });

    it("empties the list and the hint once confirmed", async () => {
      vi.spyOn(window, "confirm").mockReturnValue(true);
      api.clearPosts.mockResolvedValue(2);
      mount(row(1) + row(2, true));
      await boot();
      const submit = vi.fn((event: Event) => event.preventDefault());
      document.querySelector("form").addEventListener("submit", submit);

      button().click();
      expect(button().disabled).toBe(true);
      await tick();

      expect(api.clearPosts).toHaveBeenCalledWith(5);
      expect(document.querySelectorAll(".takedown-post")).toHaveLength(0);
      expect(statusText()).toBe("");
      expect(trackDone).toHaveBeenCalledWith("2 posts removed from takedown");
      expect(button().disabled).toBe(false);
      expect(submit).not.toHaveBeenCalled();
    });

    it("keeps the rows and re-enables the button on failure", async () => {
      vi.spyOn(window, "confirm").mockReturnValue(true);
      api.clearPosts.mockRejectedValue(new Error("nope"));
      mount(row(1));
      await boot();

      button().click();
      await tick();

      expect($id("takedown-post-1")).not.toBeNull();
      expect(button().disabled).toBe(false);
    });
  });
});
