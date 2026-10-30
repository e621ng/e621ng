import { describe, expect, it, vi } from "vitest";

const { dialogs, user } = vi.hoisted(() => ({
  dialogs: [] as FakeDialog[],
  user: { blacklist: ["wolf", "fox rating:e"] as string[] },
}));

class FakeDialog {
  constructor (public element: unknown) { dialogs.push(this); }
  open = vi.fn();
  close = vi.fn();
}

vi.mock("@/components/dialog", () => ({ default: FakeDialog }));
vi.mock("@/models/CurrentUser", () => ({ default: user }));

function render (): void {
  document.body.innerHTML = `
    <a id="blacklist-edit-link" href="#">Edit</a>
    <div id="blacklist-edit-dialog">
      <textarea id="blacklist-edit"></textarea>
      <button id="blacklist-save">Save</button>
      <button id="blacklist-cancel">Cancel</button>
    </div>`;
}

async function load () {
  dialogs.length = 0;
  const BlacklistQuickEdit = (await import("@/pages/posts/BlacklistQuickEdit")).default;
  void BlacklistQuickEdit.instance;
  return BlacklistQuickEdit;
}

const textarea = () => document.querySelector<HTMLTextAreaElement>("#blacklist-edit");

describe("BlacklistQuickEdit", () => {
  it("opens with the current blacklist and saves the edited one", async () => {
    render();
    user.blacklist = ["wolf", "fox rating:e"];
    await load();

    document.getElementById("blacklist-edit-link").click();
    expect(textarea().value).toBe("wolf\nfox rating:e");
    expect(dialogs[0].open).toHaveBeenCalledOnce();

    textarea().value = "wolf\ncat";
    document.getElementById("blacklist-save").click();
    expect(user.blacklist).toEqual(["wolf", "cat"]);
    expect(dialogs[0].close).toHaveBeenCalledOnce();
  });

  it("follows blacklist updates made elsewhere", async () => {
    render();
    await load();

    document.dispatchEvent(new CustomEvent("e621:blacklistUpdated", { detail: { blacklist: ["dog"] } }));
    expect(textarea().value).toBe("dog");
  });

  it("binds once, however often it is requested", async () => {
    render();
    const BlacklistQuickEdit = await load();
    expect(BlacklistQuickEdit.instance).toBe(BlacklistQuickEdit.instance);
    expect(dialogs).toHaveLength(1);
  });

  it("does nothing without the dialog", async () => {
    await load();
    expect(dialogs).toHaveLength(0);
  });
});
