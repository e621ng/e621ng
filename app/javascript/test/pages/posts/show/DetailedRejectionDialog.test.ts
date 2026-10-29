import { beforeEach, describe, expect, it, vi } from "vitest";

const { bulk, dialogs } = vi.hoisted(() => ({
  bulk: { disapprove: vi.fn(() => Promise.resolve()) },
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

const DIALOG_MARKUP = `
  <div id="detailed-rejection-dialog" data-title="Detailed Rejection">
    <form id="detailed-rejection-form">
      <input type="hidden" id="post_disapproval_post_id" value="x">
      <select id="post_disapproval_reason">
        <option value="borderline_relevancy">Borderline Relevancy</option>
        <option value="borderline_quality">Borderline Quality</option>
        <option value="other">Other</option>
      </select>
      <input type="text" id="post_disapproval_message">
      <button type="submit">Submit</button>
      <button type="button" id="detailed-rejection-cancel">Cancel</button>
    </form>
  </div>`;

function render ({ withDialog = true } = {}): void {
  document.body.innerHTML = `
    <div class="quick-mod">
      <a href="#" class="detailed-rejection-link" data-post-id="${POST_ID}">Disapprove</a>
    </div>`;
  if (withDialog) document.body.insertAdjacentHTML("beforeend", DIALOG_MARKUP);
}

async function load () {
  const DetailedRejectionDialog = (await import("@/pages/posts/show/DetailedRejectionDialog")).default;
  void DetailedRejectionDialog.instance;
  return DetailedRejectionDialog;
}

function open (): void {
  document.querySelector<HTMLElement>(".detailed-rejection-link")!.click();
}

describe("DetailedRejectionDialog", () => {
  beforeEach(() => {
    bulk.disapprove.mockClear();
    dialogs.length = 0;
    render();
  });

  it("builds the dialog on the first click and opens it every time", async () => {
    await load();
    expect(dialogs).toHaveLength(0);

    open();
    expect(dialogs).toHaveLength(1);
    expect(dialogs[0].open).toHaveBeenCalledTimes(1);

    open();
    expect(dialogs).toHaveLength(1);
    expect(dialogs[0].open).toHaveBeenCalledTimes(2);
    expect(dialogs[0].toggle).not.toHaveBeenCalled();
  });

  it("fills the post id and resets the form on every open", async () => {
    await load();
    open();
    expect($("#post_disapproval_post_id").val()).toBe(String(POST_ID));

    $("#post_disapproval_reason").val("other");
    $("#post_disapproval_message").val("stale message");
    $("#post_disapproval_post_id").val("999");

    open();
    expect($("#post_disapproval_post_id").val()).toBe(String(POST_ID));
    expect($("#post_disapproval_reason").val()).toBe("borderline_relevancy");
    expect($("#post_disapproval_message").val()).toBe("");
  });

  it("focuses the reason select on open", async () => {
    await load();
    open();
    expect(document.activeElement).toBe(document.getElementById("post_disapproval_reason"));
  });

  it("disapproves with the chosen reason and message, then closes", async () => {
    await load();
    open();
    $("#post_disapproval_reason").val("borderline_quality");
    $("#post_disapproval_message").val("Please clean up the lines");
    $("#detailed-rejection-form").trigger("submit");

    expect(bulk.disapprove).toHaveBeenCalledWith(POST_ID, "borderline_quality", "Please clean up the lines");
    expect(dialogs[0].close).toHaveBeenCalledTimes(1);
  });

  it("closes from the cancel button without disapproving", async () => {
    await load();
    open();
    $("#detailed-rejection-cancel").trigger("click");
    expect(dialogs[0].close).toHaveBeenCalledTimes(1);
    expect(bulk.disapprove).not.toHaveBeenCalled();
  });

  it("does nothing when the dialog partial is not rendered", async () => {
    render({ withDialog: false });
    const DetailedRejectionDialog = await load();
    open();
    expect(dialogs).toHaveLength(0);
    expect(DetailedRejectionDialog.instance.isOpen).toBe(false);
  });
});
