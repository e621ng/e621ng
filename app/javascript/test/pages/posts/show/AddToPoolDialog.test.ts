import { beforeEach, describe, expect, it, vi } from "vitest";
import { htmlResponse, jsonResponse, setMeta, setSiteData } from "../../../helpers";

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

function render (): void {
  document.body.dataset.controller = "posts";
  document.body.dataset.action = "show";
  document.body.innerHTML = `
    <a href="#" class="add-to-pool">Add to pool</a>
    <button class="add-to-pool">Add to Pool</button>
    <form id="add-to-pool-dialog" data-title="Add to Pool">
      <input type="hidden" name="post_id" value="${POST_ID}">
      <div class="input dialog-inputs"><input type="text" id="pool_name" name="pool_name"></div>
      <div class="dialog-recent" hidden><ul id="recent-pools"></ul></div>
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
  const AddToPoolDialog = (await import("@/pages/posts/show/AddToPoolDialog")).default;
  const reload = vi.spyOn(AddToPoolDialog as any, "reloadPage").mockImplementation(() => {});
  void AddToPoolDialog.instance;
  return { AddToPoolDialog, reload };
}

function recentResponse (pools: unknown[] = []) {
  return jsonResponse(pools);
}

function open (): void {
  document.querySelector<HTMLElement>("a.add-to-pool")!.click();
}

async function submit (name: string): Promise<void> {
  $("#pool_name").val(name);
  $("#add-to-pool-dialog").trigger("submit");
  await vi.waitFor(() => expect($("button[type=submit]").prop("disabled")).toBe(false));
}

describe("AddToPoolDialog", () => {
  beforeEach(() => {
    alertSpy.mockReset();
    dialogs.length = 0;
    render();
  });

  it("builds the dialog on the first trigger click and toggles it afterwards", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(recentResponse());
    await load();

    expect(dialogs).toHaveLength(0);
    open();
    expect(dialogs).toHaveLength(1);
    expect(dialogs[0].toggle).toHaveBeenCalledTimes(1);

    document.querySelector<HTMLElement>("button.add-to-pool")!.click();
    expect(dialogs).toHaveLength(1);
    expect(dialogs[0].toggle).toHaveBeenCalledTimes(2);
  });

  it("does nothing off the posts#show page", async () => {
    document.body.dataset.action = "index";
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(recentResponse());
    await load();
    open();
    expect(dialogs).toHaveLength(0);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("loads recent pools once, rendering names as text", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(recentResponse([
      { id: 1, name: "cool_pool" },
      { id: 2, name: "<img src=x onerror=alert(1)>" },
    ]));
    await load();
    open();
    await vi.waitFor(() => expect($("#recent-pools li")).toHaveLength(2));

    expect(fetchSpy.mock.calls[0][0]).toBe("/pool_element/recent");
    expect($(".dialog-recent").prop("hidden")).toBe(false);
    const items = $("#recent-pools li");
    expect(items.eq(0).text()).toBe("cool_pool");
    expect(items.eq(1).text()).toBe("<img src=x onerror=alert(1)>");
    expect(items.eq(1).attr("data-value")).toBe("<img src=x onerror=alert(1)>");
    expect(document.querySelector("#recent-pools img")).toBeNull();

    open();
    open();
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it("keeps the recent block hidden when there are no recent pools", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(recentResponse([]));
    await load();
    open();
    await Promise.resolve();
    expect($(".dialog-recent").prop("hidden")).toBe(true);
  });

  it("fills the name field when a recent pool is clicked", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(recentResponse([{ id: 1, name: "cool_pool" }]));
    await load();
    open();
    await vi.waitFor(() => expect($("#recent-pools li")).toHaveLength(1));

    $("#recent-pools li").first().trigger("click");
    expect($("#pool_name").val()).toBe("cool_pool");
  });

  it("alerts on an empty name without sending a request", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(recentResponse());
    await load();
    await submit("   ");
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(alertSpy).toHaveBeenCalledWith("Error: No pool specified");
  });

  it("posts the pool name and post id, then reloads on success", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ id: 1 }));
    const { reload } = await load();
    await submit("cool_pool");

    const [url, init] = fetchSpy.mock.calls[0];
    expect(url).toBe("/pool_element.json");
    expect(init?.method).toBe("POST");
    expect(String(init?.body)).toBe(`pool_name=cool_pool&post_id=${POST_ID}`);
    expect((init?.headers as Record<string, string>)["X-CSRF-Token"]).toBe("tok");
    expect(reload).toHaveBeenCalledTimes(1);
    expect(alertSpy).not.toHaveBeenCalled();
  });

  it("shows Not Found for an unknown pool and does not reload", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(htmlResponse(404));
    const { reload } = await load();
    await submit("nope");
    expect(alertSpy).toHaveBeenCalledWith("Error: Not Found");
    expect(reload).not.toHaveBeenCalled();
  });

  it("joins validation errors from a responders error hash", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse({ errors: { base: ["Pools can only have up to 1000 posts each"], updater: ["is limited"] } }, { status: 422 }),
    );
    await load();
    await submit("full_pool");
    expect(alertSpy).toHaveBeenCalledWith("Error: Pools can only have up to 1000 posts each; is limited");
  });

  it("falls back to the status line for a non-JSON failure", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue({ ...htmlResponse(500), statusText: "Internal Server Error" });
    await load();
    await submit("cool_pool");
    expect(alertSpy).toHaveBeenCalledWith("Error: 500 Internal Server Error");
  });

  it("disables the submit button while the request is pending", async () => {
    let resolve!: (value: unknown) => void;
    vi.spyOn(globalThis, "fetch").mockReturnValue(new Promise((r) => { resolve = r; }));
    await load();

    $("#pool_name").val("cool_pool");
    $("#add-to-pool-dialog").trigger("submit");
    expect($("button[type=submit]").prop("disabled")).toBe(true);

    resolve(jsonResponse({}, { status: 422 }));
    await vi.waitFor(() => expect($("button[type=submit]").prop("disabled")).toBe(false));
  });

  it("closes the dialog from the cancel button", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(recentResponse());
    await load();
    open();
    $("button[name=cancel]").trigger("click");
    expect(dialogs[0].close).toHaveBeenCalledTimes(1);
  });
});
