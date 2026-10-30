import { beforeEach, describe, expect, it, vi } from "vitest";

const { bulk, dialogs } = vi.hoisted(() => ({
  bulk: { delete: vi.fn(() => Promise.resolve()) },
  dialogs: [] as FakeDialog[],
}));

class FakeDialog {
  isOpen = false;
  constructor (public element: unknown) { dialogs.push(this); }
  open = vi.fn(() => { this.isOpen = true; });
  close = vi.fn(() => { this.isOpen = false; });
  toggle = vi.fn(() => { this.isOpen = !this.isOpen; });
}

vi.mock("@/components/dialog", () => ({ default: FakeDialog }));
vi.mock("@/pages/posts/BulkActions", () => ({ default: bulk }));

const POST_ID = 42;
const CANNED_REASON = "Does not meet minimum quality standards (Artistic)";
const FLAG_REASON = "Inferior version of post #41";

function dialogMarkup (withDmail: boolean, dmailChecked: boolean): string {
  const checked = dmailChecked ? "checked" : "";
  const dmailOption = `
      <label><input type="checkbox" id="delete-with-reason-dialog-enable-dmail" ${checked}
        data-dmail-message="Your post #${POST_ID} was deleted" data-dmail-title="Post deleted"></label>`;
  return `
    <form class="simple_form" id="delete-with-reason-dialog" data-title="Delete Post">
      <div id="delete-with-reason-dialog-labeled-input">
        <label for="delete-with-reason-dialog-input">Reason</label>
        <input type="text" id="delete-with-reason-dialog-input">
      </div>
      ${withDmail ? dmailOption : ""}
      <button type="button" id="delete-with-reason-dialog-cancel">Cancel</button>
      <button type="submit" id="delete-with-reason-dialog-ok">OK</button>
    </form>`;
}

function render ({ withDialog = true, withDmail = true, dmailChecked = false } = {}): void {
  document.body.innerHTML = `
    <a href="#" class="delete-with-reason-link flag" data-post-id="${POST_ID}" data-reason="${FLAG_REASON}" data-from-flag="true" data-move-favs="true">Delete with given reason</a>
    <div class="quick-mod">
      <a href="#" class="delete-with-reason-link canned" data-post-id="${POST_ID}" data-reason="${CANNED_REASON}">Artistic</a>
    </div>`;
  if (withDialog) document.body.insertAdjacentHTML("beforeend", dialogMarkup(withDmail, dmailChecked));
}

async function load () {
  const DeleteWithReasonDialog = (await import("@/pages/posts/show/DeleteWithReasonDialog")).default;
  void DeleteWithReasonDialog.instance;
  return DeleteWithReasonDialog;
}

function open (which: "canned" | "flag"): void {
  document.querySelector<HTMLElement>(`.delete-with-reason-link.${which}`)!.click();
}

function submit (): void {
  $("#delete-with-reason-dialog").trigger("submit");
}

describe("DeleteWithReasonDialog", () => {
  beforeEach(() => {
    bulk.delete.mockClear();
    dialogs.length = 0;
    render();
  });

  it("builds the dialog on the first click and opens it every time", async () => {
    await load();
    expect(dialogs).toHaveLength(0);

    open("canned");
    expect(dialogs).toHaveLength(1);
    expect(dialogs[0].open).toHaveBeenCalledTimes(1);

    open("flag");
    expect(dialogs).toHaveLength(1);
    expect(dialogs[0].open).toHaveBeenCalledTimes(2);
  });

  it("shows and prefills the reason input for a canned reason, and focuses it", async () => {
    await load();
    open("canned");
    expect($("#delete-with-reason-dialog-labeled-input").prop("hidden")).toBe(false);
    expect($("#delete-with-reason-dialog-input").val()).toBe(CANNED_REASON);
    expect(document.activeElement).toBe(document.getElementById("delete-with-reason-dialog-input"));
  });

  it("deletes with the edited reason", async () => {
    await load();
    open("canned");
    $("#delete-with-reason-dialog-input").val(CANNED_REASON + ", see the wiki");
    submit();

    expect(bulk.delete).toHaveBeenCalledWith(POST_ID, CANNED_REASON + ", see the wiki", {
      reload: true,
      from_flag: false,
      move_favorites: false,
      dmail: null,
      dmail_title: null,
    });
  });

  it("hides the input and focuses OK when deleting for the flag's reason", async () => {
    await load();
    open("flag");
    expect($("#delete-with-reason-dialog-labeled-input").prop("hidden")).toBe(true);
    expect(document.activeElement).toBe(document.getElementById("delete-with-reason-dialog-ok"));
  });

  it("deletes with the flag's reason, ignoring the input, and moves favorites", async () => {
    await load();
    open("canned");
    $("#delete-with-reason-dialog-input").val("leftover text");
    open("flag");
    submit();

    expect(bulk.delete).toHaveBeenCalledWith(POST_ID, FLAG_REASON, expect.objectContaining({
      from_flag: true,
      move_favorites: true,
    }));
  });

  it("uses the link clicked most recently", async () => {
    await load();
    open("flag");
    open("canned");
    submit();
    expect(bulk.delete).toHaveBeenCalledWith(POST_ID, CANNED_REASON, expect.objectContaining({ from_flag: false, move_favorites: false }));
  });

  it("sends the dmail template when the option is checked", async () => {
    render({ dmailChecked: true });
    await load();
    open("canned");
    submit();

    expect(bulk.delete).toHaveBeenCalledWith(POST_ID, CANNED_REASON, expect.objectContaining({
      dmail: `Your post #${POST_ID} was deleted`,
      dmail_title: "Post deleted",
    }));
  });

  it("sends no dmail when the option is unchecked", async () => {
    await load();
    open("canned");
    $("#delete-with-reason-dialog-enable-dmail").prop("checked", false);
    submit();
    expect(bulk.delete).toHaveBeenCalledWith(POST_ID, CANNED_REASON, expect.objectContaining({ dmail: null, dmail_title: null }));
  });

  it("sends no dmail when no template is configured", async () => {
    render({ withDmail: false });
    await load();
    open("canned");
    submit();
    expect(bulk.delete).toHaveBeenCalledWith(POST_ID, CANNED_REASON, expect.objectContaining({ dmail: null, dmail_title: null }));
  });

  it("does not submit on Enter pressed outside the dialog", async () => {
    await load();
    open("canned");
    document.body.appendChild(document.createElement("input")).focus();
    document.activeElement!.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", bubbles: true }));
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", bubbles: true }));
    expect(bulk.delete).not.toHaveBeenCalled();
  });

  it("does nothing on submit before any link was clicked", async () => {
    await load();
    submit();
    expect(bulk.delete).not.toHaveBeenCalled();
  });

  it("closes from the cancel button without deleting", async () => {
    await load();
    open("canned");
    $("#delete-with-reason-dialog-cancel").trigger("click");
    expect(dialogs[0].close).toHaveBeenCalledTimes(1);
    expect(bulk.delete).not.toHaveBeenCalled();
  });

  it("does nothing when the dialog partial is not rendered", async () => {
    render({ withDialog: false });
    const DeleteWithReasonDialog = await load();
    open("canned");
    expect(dialogs).toHaveLength(0);
    expect(DeleteWithReasonDialog.instance.isOpen).toBe(false);
  });
});
