import { beforeEach, describe, expect, it, vi } from "vitest";

const post = { update: vi.fn() };
const toast = { notice: vi.fn(), alert: vi.fn(), create: vi.fn(() => ({ message: "", timeout: 0 })), dismiss: vi.fn() };
const hotkeys = { enabled: true, register: vi.fn() };
const rails = { enableElement: vi.fn() };

vi.mock("@/models/Post", async (importOriginal) => ({ ...await importOriginal<object>(), default: post }));
vi.mock("@/utility/Toast", async (importOriginal) => ({ ...await importOriginal<object>(), default: toast }));
vi.mock("@/core/hotkeys", () => ({ default: hotkeys }));
vi.mock("@rails/ujs", () => ({ default: rails }));
vi.mock("@/models/CurrentUser", () => ({ default: { is: {}, settings: {} } }));

const POST_ID = 7;

function render () {
  document.body.innerHTML = `
    <div id="quick-edit-div" inert>
      <div class="quick-edit-body">
        <form id="quick-edit-form">
          <textarea id="post_tag_string"></textarea>
          <input type="submit" value="Submit">
          <button type="button" id="quick-edit-cancel">Cancel</button>
        </form>
      </div>
    </div>
    <div id="posts">
      <article class="thumbnail" data-id="${POST_ID}" data-rating="s" data-tags="fox red" data-flags=""></article>
    </div>`;
}

async function load () {
  const QuickEdit = (await import("@/pages/posts/QuickEdit")).default;
  return QuickEdit.instance;
}

const container = () => document.getElementById("quick-edit-div");
const textarea = () => document.querySelector<HTMLTextAreaElement>("#post_tag_string");
const submit = () => document.querySelector<HTMLFormElement>("#quick-edit-form").dispatchEvent(new Event("submit", { cancelable: true }));
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

describe("QuickEdit", () => {
  beforeEach(() => {
    render();
    hotkeys.enabled = true;
    post.update.mockReset().mockResolvedValue({ id: POST_ID, tags: "fox blue", rating: "s", flags: "" });
    toast.notice.mockReset();
    rails.enableElement.mockReset();
  });

  it("opens with the cached tags, focused at the end, with hotkeys off", async () => {
    const QuickEdit = await load();
    QuickEdit.open(POST_ID);

    expect(QuickEdit.postID).toBe(POST_ID);
    expect(container().classList.contains("open")).toBe(true);
    expect(container().hasAttribute("inert")).toBe(false);
    expect(textarea().value).toBe("fox red ");
    expect(document.activeElement).toBe(textarea());
    expect(textarea().selectionStart).toBe("fox red ".length);
    expect(hotkeys.enabled).toBe(false);
  });

  it("ignores posts that are not on the page", async () => {
    const QuickEdit = await load();
    QuickEdit.open(999);
    expect(QuickEdit.postID).toBeNull();
    expect(container().classList.contains("open")).toBe(false);
  });

  it("submits the edited tags along with the tags it started from", async () => {
    const QuickEdit = await load();
    QuickEdit.open(POST_ID);
    textarea().value = "fox blue";

    submit();
    await flush();

    expect(post.update).toHaveBeenCalledWith(POST_ID, { tag_string: "fox blue", old_tag_string: "fox red" });
    expect(document.querySelector("article.thumbnail").getAttribute("data-tags")).toBe("fox blue");
    expect(toast.notice).toHaveBeenCalledWith(`Post #${POST_ID} updated`);
    expect(QuickEdit.postID).toBeNull();
    expect(container().hasAttribute("inert")).toBe(true);
    expect(hotkeys.enabled).toBe(true);
    expect(rails.enableElement).toHaveBeenCalled();
  });

  it("stays open when the update fails", async () => {
    post.update.mockRejectedValue(new Error("nope"));
    const QuickEdit = await load();
    QuickEdit.open(POST_ID);

    submit();
    await flush();

    expect(QuickEdit.postID).toBe(POST_ID);
    expect(hotkeys.enabled).toBe(false);
    expect(rails.enableElement).toHaveBeenCalled();
  });

  it("closes on Cancel", async () => {
    const QuickEdit = await load();
    QuickEdit.open(POST_ID);

    document.getElementById("quick-edit-cancel").click();
    expect(QuickEdit.postID).toBeNull();
    expect(container().classList.contains("open")).toBe(false);
    expect(hotkeys.enabled).toBe(true);
  });

  it("closes on Escape unless something else handled it", async () => {
    const QuickEdit = await load();
    QuickEdit.open(POST_ID);

    // e.g. an open autocomplete dropdown
    textarea().addEventListener("keydown", (event) => event.preventDefault(), { once: true });
    textarea().dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true }));
    expect(QuickEdit.postID).toBe(POST_ID);

    textarea().dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true }));
    expect(QuickEdit.postID).toBeNull();
  });

  it("leaves hotkeys alone when closing an editor that is not open", async () => {
    const QuickEdit = await load();
    hotkeys.enabled = false;
    QuickEdit.close();
    expect(hotkeys.enabled).toBe(false);
  });
});
