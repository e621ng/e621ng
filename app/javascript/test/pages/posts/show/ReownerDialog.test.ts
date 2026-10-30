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
}

vi.mock("@/components/dialog", () => ({ default: FakeDialog }));
vi.mock("@/utility/Toast", () => ({ default: { alert: (msg: string) => alertSpy(msg), create: vi.fn(), notice: vi.fn() } }));

const POST_ID = 42;
const OWNERS = [{ id: 5, name: "alice" }, { id: 6, name: "bob" }];

const BD_STAFF_OPTIONS = `
  <input type="checkbox" id="reowner-dialog-reowner-versions">
  <input type="checkbox" id="reowner-dialog-post-events" checked>
  <input type="checkbox" id="reowner-dialog-karma" checked>`;

function render ({ allowOther = false, bdStaff = false } = {}): void {
  document.body.innerHTML = `
    <a href="#" id="reowner-post-link">Reowner</a>
    <form id="reowner-dialog" data-title="Reowner Post">
      <div class="input">
        <div id="reowner-dialog-status"></div>
        <select id="reowner-dialog-select" data-allow-other="${allowOther}"></select>
        <input type="text" id="reowner-dialog-input">
        ${bdStaff ? BD_STAFF_OPTIONS : ""}
      </div>
      <button type="button" id="reowner-dialog-cancel">Cancel</button>
      <button type="submit" id="reowner-dialog-ok">OK</button>
    </form>`;
  setSiteData("post-data", { id: POST_ID });
  setSiteData("site-user", {});
  setMeta("csrf-token", "tok");
}

async function load () {
  const ReownerDialog = (await import("@/pages/posts/show/ReownerDialog")).default;
  const reload = vi.spyOn(ReownerDialog as any, "reloadPage").mockImplementation(() => {});
  void ReownerDialog.instance;
  return { ReownerDialog, reload };
}

function stubFetch (owners: unknown = jsonResponse(OWNERS), reownerResponse: unknown = jsonResponse({ id: POST_ID })) {
  return vi.spyOn(globalThis, "fetch").mockImplementation(async (url) => {
    if (String(url).includes("previous_owners")) return owners as Response;
    return reownerResponse as Response;
  });
}

async function open (): Promise<void> {
  document.querySelector<HTMLElement>("#reowner-post-link")!.click();
  await vi.waitFor(() => expect($("#reowner-dialog-status").text()).not.toBe("Loading..."));
}

async function submit (): Promise<void> {
  $("#reowner-dialog").trigger("submit");
  await vi.waitFor(() => expect(fetchCalls("reowner.json")).toHaveLength(1));
  await vi.waitFor(() => expect(ok().disabled).toBe(!$("#reowner-dialog-input").val()));
}

let fetchSpy: ReturnType<typeof stubFetch>;
const fetchCalls = (fragment: string) => fetchSpy.mock.calls.filter(([url]) => String(url).includes(fragment));
const ok = () => document.querySelector<HTMLButtonElement>("#reowner-dialog-ok")!;
const input = () => document.querySelector<HTMLInputElement>("#reowner-dialog-input")!;
const select = () => document.querySelector<HTMLSelectElement>("#reowner-dialog-select")!;

describe("ReownerDialog", () => {
  beforeEach(() => {
    alertSpy.mockReset();
    dialogs.length = 0;
  });

  it("builds the dialog lazily and lists previous owners, preselecting the first", async () => {
    render();
    fetchSpy = stubFetch();
    await load();
    expect(dialogs).toHaveLength(0);

    await open();
    expect(dialogs).toHaveLength(1);
    expect(dialogs[0].open).toHaveBeenCalledTimes(1);
    expect(fetchSpy.mock.calls[0][0]).toBe(`/staff/post/posts/${POST_ID}/previous_owners.json`);

    expect($("#reowner-dialog-select option").map((_, o) => $(o).text()).get()).toEqual(["alice (5)", "bob (6)"]);
    expect(select().hidden).toBe(false);
    expect(input().hidden).toBe(true);
    expect(input().value).toBe("!5");
    expect(ok().disabled).toBe(false);
  });

  it("mirrors the selected owner into the input", async () => {
    render();
    fetchSpy = stubFetch();
    await load();
    await open();

    $(select()).val("6").trigger("change");
    expect(input().value).toBe("!6");
  });

  it("reveals a free-form input for admins via \"Other...\"", async () => {
    render({ allowOther: true });
    fetchSpy = stubFetch();
    await load();
    await open();

    $(select()).val("0").trigger("change");
    expect(input().hidden).toBe(false);
    expect(input().disabled).toBe(false);
    expect(input().value).toBe("");
    expect(ok().disabled).toBe(true);

    $(input()).val("carol").trigger("input");
    expect(ok().disabled).toBe(false);
  });

  it("keeps OK disabled when there are no previous owners and no \"Other...\"", async () => {
    render();
    fetchSpy = stubFetch(jsonResponse([]));
    await load();
    await open();

    expect($("#reowner-dialog-status").text()).toBe("No previous owners found.");
    expect(select().hidden).toBe(true);
    expect(ok().disabled).toBe(true);
  });

  it("refuses to submit without an owner", async () => {
    render();
    fetchSpy = stubFetch(jsonResponse([]));
    await load();
    await open();

    $("#reowner-dialog").trigger("submit");
    expect(fetchCalls("reowner.json")).toHaveLength(0);
  });

  it("posts only the new owner when the option checkboxes are absent, then reloads", async () => {
    render();
    fetchSpy = stubFetch();
    const { reload } = await load();
    await open();
    await submit();

    const [url, init] = fetchCalls("reowner.json")[0];
    expect(url).toBe(`/staff/post/posts/${POST_ID}/reowner.json`);
    expect(init?.method).toBe("POST");
    expect(String(init?.body)).toBe("reowner%5Bnew_owner%5D=%215");
    expect((init?.headers as Record<string, string>)["X-CSRF-Token"]).toBe("tok");
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it("sends the option checkboxes for BD staff", async () => {
    render({ bdStaff: true });
    fetchSpy = stubFetch();
    await load();
    await open();
    $("#reowner-dialog-karma").prop("checked", false);
    await submit();

    const params = new URLSearchParams(String(fetchCalls("reowner.json")[0][1]?.body));
    expect(Object.fromEntries(params)).toEqual({
      "reowner[new_owner]": "!5",
      "reowner[reowner_versions]": "false",
      "reowner[post_events]": "true",
      "reowner[karma]": "false",
    });
  });

  it("shows the backend message on failure and does not reload", async () => {
    render();
    fetchSpy = stubFetch(jsonResponse(OWNERS), jsonResponse({ success: false, message: "New owner could not be found." }, { status: 422 }));
    const { reload } = await load();
    await open();
    await submit();

    expect(alertSpy).toHaveBeenCalledWith("Error: New owner could not be found.");
    expect(reload).not.toHaveBeenCalled();
    expect(ok().disabled).toBe(false);
  });

  it("ignores repeat submits while a request is in flight", async () => {
    render();
    let resolve!: (r: Response) => void;
    fetchSpy = stubFetch(jsonResponse(OWNERS), new Promise<Response>((r) => { resolve = r; }));
    const { reload } = await load();
    await open();

    $("#reowner-dialog").trigger("submit");
    $("#reowner-dialog").trigger("submit");
    expect(ok().disabled).toBe(true);
    expect(fetchCalls("reowner.json")).toHaveLength(1);

    resolve(jsonResponse({ id: POST_ID }));
    await vi.waitFor(() => expect(reload).toHaveBeenCalledTimes(1));
  });

  it("alerts when the owner list cannot be loaded", async () => {
    render();
    fetchSpy = stubFetch(jsonResponse({ reason: "Access denied" }, { status: 403 }));
    await load();
    await open();

    expect(alertSpy).toHaveBeenCalledWith("Error: Access denied");
    expect($("#reowner-dialog-status").text()).toBe("No previous owners found.");
  });

  it("drops a stale owner list from an earlier open", async () => {
    render();
    let resolveFirst!: (r: Response) => void;
    let calls = 0;
    fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(async () => {
      if (calls++ === 0) return new Promise<Response>((r) => { resolveFirst = r; });
      return jsonResponse([{ id: 9, name: "newest" }]);
    });
    await load();

    document.querySelector<HTMLElement>("#reowner-post-link")!.click();
    await open();
    resolveFirst(jsonResponse(OWNERS));
    await new Promise((r) => setTimeout(r));

    expect($("#reowner-dialog-select option").map((_, o) => $(o).text()).get()).toEqual(["newest (9)"]);
  });

  it("closes the dialog from the cancel button", async () => {
    render();
    fetchSpy = stubFetch();
    await load();
    await open();
    $("#reowner-dialog-cancel").trigger("click");
    expect(dialogs[0].close).toHaveBeenCalledTimes(1);
  });

  it("does nothing when the dialog is not rendered (non-janitors)", async () => {
    document.body.innerHTML = "";
    setSiteData("post-data", { id: POST_ID });
    const { ReownerDialog } = await load();
    expect(ReownerDialog.instance.isOpen).toBe(false);
  });
});
