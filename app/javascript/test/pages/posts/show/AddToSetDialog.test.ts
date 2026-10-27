import { beforeEach, describe, expect, it, vi } from "vitest";
import { jsonResponse, setMeta, setSiteData } from "../../../helpers";

const { alertSpy, dialogs } = vi.hoisted(() => ({
  alertSpy: vi.fn(),
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
vi.mock("@/utility/Toast", () => ({ default: { alert: (msg: string) => alertSpy(msg), create: vi.fn(), notice: vi.fn() } }));

const POST_ID = 42;
const FOR_SELECT = { Owned: [["my set", 7], ["other set", 8]], Maintained: [["shared set", 9]] };

function render (): void {
  document.body.dataset.controller = "posts";
  document.body.dataset.action = "show";
  document.body.innerHTML = `
    <a href="#" class="add-to-set">Add to set</a>
    <form id="add-to-set-dialog" data-title="Add to Set">
      <div class="input dialog-inputs">
        <select id="add-to-set-id"><option>Loading...</option></select>
      </div>
      <div class="input dialog-submit">
        <button type="button" name="cancel">Cancel</button>
        <button type="submit">Submit</button>
      </div>
    </form>`;
  setSiteData("post-data", { id: POST_ID });
  setSiteData("site-user", {});
  setMeta("csrf-token", "tok");
}

async function load () {
  const AddToSetDialog = (await import("@/pages/posts/show/AddToSetDialog")).default;
  const reload = vi.spyOn(AddToSetDialog as any, "reloadPage").mockImplementation(() => {});
  void AddToSetDialog.instance;
  return { AddToSetDialog, reload };
}

/** Routes the select loader and the add request to their own responses */
function stubFetch (addResponse: unknown = jsonResponse({ id: 7 })) {
  return vi.spyOn(globalThis, "fetch").mockImplementation(async (url) => {
    if (String(url).includes("for_select")) return jsonResponse(FOR_SELECT);
    return addResponse as Response;
  });
}

async function open (): Promise<void> {
  document.querySelector<HTMLElement>("a.add-to-set")!.click();
  await vi.waitFor(() => expect($("#add-to-set-id optgroup")).toHaveLength(2));
}

async function submit (): Promise<void> {
  $("#add-to-set-dialog").trigger("submit");
  await vi.waitFor(() => expect($("button[type=submit]").prop("disabled")).toBe(false));
}

describe("AddToSetDialog", () => {
  beforeEach(() => {
    alertSpy.mockReset();
    dialogs.length = 0;
    render();
  });

  it("builds the dialog lazily and fills the select with grouped sets on open", async () => {
    const fetchSpy = stubFetch();
    await load();
    expect(dialogs).toHaveLength(0);

    await open();
    expect(dialogs).toHaveLength(1);
    expect(dialogs[0].toggle).toHaveBeenCalledTimes(1);
    expect(fetchSpy.mock.calls[0][0]).toBe("/post_sets/for_select.json");

    const groups = $("#add-to-set-id optgroup");
    expect(groups.eq(0).attr("label")).toBe("Owned");
    expect(groups.eq(0).find("option").map((_, o) => $(o).text()).get()).toEqual(["my set", "other set"]);
    expect(groups.eq(1).attr("label")).toBe("Maintained");
    expect(groups.eq(1).find("option").val()).toBe("9");
  });

  it("preselects the remembered set and stores changes as a number", async () => {
    stubFetch();
    localStorage.setItem("set", "8");
    await load();
    await open();

    expect($("#add-to-set-id").val()).toBe("8");

    $("#add-to-set-id").val("9").trigger("change");
    const LStorage = (await import("@/utility/storage/Local")).default;
    expect(LStorage.Posts.Set).toBe(9);
  });

  it("refreshes the set list only when opening, not when closing", async () => {
    const fetchSpy = stubFetch();
    await load();
    await open();
    expect(fetchSpy).toHaveBeenCalledTimes(1);

    document.querySelector<HTMLElement>("a.add-to-set")!.click(); // close
    expect(fetchSpy).toHaveBeenCalledTimes(1);

    document.querySelector<HTMLElement>("a.add-to-set")!.click(); // open again
    expect(fetchSpy).toHaveBeenCalledTimes(2);
  });

  it("posts the current post to the chosen set and reloads", async () => {
    const fetchSpy = stubFetch();
    const { reload } = await load();
    await open();
    $("#add-to-set-id").val("8");
    await submit();

    const [url, init] = fetchSpy.mock.calls[1];
    expect(url).toBe("/post_sets/8/add_posts.json");
    expect(init?.method).toBe("POST");
    expect(String(init?.body)).toBe(`post_ids%5B%5D=${POST_ID}`);
    expect((init?.headers as Record<string, string>)["X-CSRF-Token"]).toBe("tok");
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it("shows the backend message on failure and does not reload", async () => {
    stubFetch(jsonResponse({ message: "This set contains too many posts and can no longer be edited." }, { status: 422 }));
    const { reload } = await load();
    await open();
    await submit();

    expect(alertSpy).toHaveBeenCalledWith("Error: This set contains too many posts and can no longer be edited.");
    expect(reload).not.toHaveBeenCalled();
  });

  it("alerts without a request when no set is selected", async () => {
    const fetchSpy = stubFetch();
    await load();
    // Never opened: the select still holds the placeholder
    await submit();

    expect(fetchSpy).not.toHaveBeenCalled();
    expect(alertSpy).toHaveBeenCalledWith("Error: No set specified");
  });

  it("alerts when the set list cannot be loaded", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ reason: "Access denied" }, { status: 403 }));
    await load();
    document.querySelector<HTMLElement>("a.add-to-set")!.click();
    await vi.waitFor(() => expect(alertSpy).toHaveBeenCalledWith("Error getting sets list: Access denied"));
  });

  it("closes the dialog from the cancel button", async () => {
    stubFetch();
    await load();
    await open();
    $("button[name=cancel]").trigger("click");
    expect(dialogs[0].close).toHaveBeenCalledTimes(1);
  });
});
