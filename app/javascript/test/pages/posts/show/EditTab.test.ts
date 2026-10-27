import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { setSiteData } from "../../../helpers";

const hotkeys = { enabled: true, register: vi.fn() };
vi.mock("@/core/hotkeys", () => ({ default: hotkeys }));

function render ({ withForm = true, oldSource = "", source = "" } = {}) {
  $("body").append(`
    <a id="side-edit-link" href="#edit">Edit</a>
    <button type="button" id="post-edit-link">Edit</button>
  `);
  if (!withForm) return;
  $("body").append(`
    <section id="edit" style="display: none;">
      <button type="button" id="post-edit-close"><svg></svg><span>Cancel</span></button>
      <form id="form">
        <input type="hidden" name="post[old_source]" value="${oldSource}">
        <textarea id="post_source">${source}</textarea>
        <div id="post-edit-invalid-url-error"></div>
        <div id="post-edit-invalid-url-warning"></div>
        <input type="submit" value="Submit">
      </form>
    </section>
    <textarea id="post_tag_string"></textarea>
  `);
}

async function load ({ anonymous = false } = {}) {
  setSiteData("site-user", { id: anonymous ? 0 : 5, is: { anonymous } });
  const EditTab = (await import("@/pages/posts/show/EditTab")).default;
  EditTab.initialize();
  return EditTab;
}

function events () {
  const seen: string[] = [];
  $(document).on("danbooru:open-post-edit-tab.spec", () => { seen.push("open"); });
  $(document).on("danbooru:close-post-edit-tab.spec", () => { seen.push("close"); });
  return seen;
}

const editDisplay = () => document.getElementById("edit")?.style.display;
const errorDisplay = () => document.getElementById("post-edit-invalid-url-error").style.display;
const warningDisplay = () => document.getElementById("post-edit-invalid-url-warning").style.display;
const submitDisabled = () => $("#form input[type=submit]").prop("disabled");

describe("EditTab", () => {
  beforeEach(() => {
    hotkeys.enabled = true;
    vi.spyOn(window, "scrollTo").mockImplementation(() => {});
  });
  afterEach(() => { $(document).off(".edittab .spec"); });

  it("opens from the sidebar link", async () => {
    render();
    const seen = events();
    const EditTab = await load();

    $("#side-edit-link").trigger("click");

    expect(EditTab.editing).toBe(true);
    expect(editDisplay()).not.toBe("none");
    expect(seen).toEqual(["open"]);
    expect(hotkeys.enabled).toBe(false);
    expect(window.scrollTo).toHaveBeenCalledWith(expect.objectContaining({ behavior: "smooth" }));
  });

  it("closes from the icon inside the cancel button", async () => {
    render();
    const seen = events();
    const EditTab = await load();
    EditTab.open();

    $("#post-edit-close svg").trigger("click");

    expect(EditTab.editing).toBe(false);
    expect(editDisplay()).toBe("none");
    expect(seen).toEqual(["open", "close"]);
    expect(hotkeys.enabled).toBe(true);
  });

  it("toggles from the toolbar button", async () => {
    render();
    const EditTab = await load();

    $("#post-edit-link").trigger("click");
    expect(EditTab.editing).toBe(true);
    $("#post-edit-link").trigger("click");
    expect(EditTab.editing).toBe(false);
    expect(editDisplay()).toBe("none");
  });

  it("does nothing for anonymous users", async () => {
    render();
    const seen = events();
    const EditTab = await load({ anonymous: true });

    $("#side-edit-link").trigger("click");

    expect(EditTab.editing).toBe(false);
    expect(editDisplay()).toBe("none");
    expect(seen).toEqual([]);
  });

  it("does nothing when the form is not rendered", async () => {
    render({ withForm: false });
    const seen = events();
    const EditTab = await load();

    $("#side-edit-link").trigger("click");

    expect(EditTab.editing).toBe(false);
    expect(seen).toEqual([]);
  });

  describe("source validation", () => {
    it("blocks submission while a new source is invalid", async () => {
      render({ source: "https://ok.example\nnot a url" });
      await load();

      $("#side-edit-link").trigger("click");
      expect(errorDisplay()).toBe("");
      expect(submitDisabled()).toBe(true);

      $("#post_source").val("https://ok.example\nhttps://fixed.example").trigger("change");
      expect(errorDisplay()).toBe("none");
      expect(submitDisabled()).toBe(false);
      expect(warningDisplay()).toBe("none");
    });

    it("only warns about pre-existing invalid sources", async () => {
      render({ oldSource: "garbage", source: "garbage\nhttps://ok.example" });
      await load();

      $("#side-edit-link").trigger("click");
      expect(errorDisplay()).toBe("none");
      expect(submitDisabled()).toBe(false);
      expect(warningDisplay()).toBe("");

      $("#post_source").val("https://ok.example").trigger("change");
      expect(warningDisplay()).toBe("none");
    });
  });
});
