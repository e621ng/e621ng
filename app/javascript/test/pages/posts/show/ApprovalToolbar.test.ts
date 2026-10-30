import { beforeEach, describe, expect, it } from "vitest";

function render ({ withToggle = true, enabled = false } = {}): void {
  document.body.innerHTML = `
    <ul>${withToggle ? `<li><a href="#" id="janitor-toolbar-toggle">Approvals: ${enabled ? "On" : "Off"}</a></li>` : ""}</ul>
    <div class="notice notice-pending ${enabled ? "enabled" : ""}" id="pending-approval-notice"></div>`;
}

async function load () {
  const ApprovalToolbar = (await import("@/pages/posts/show/ApprovalToolbar")).default;
  const CStorage = (await import("@/utility/storage/Cookie")).default;
  void ApprovalToolbar.instance;
  return { ApprovalToolbar, CStorage };
}

function click (): void {
  document.querySelector<HTMLElement>("#janitor-toolbar-toggle")!.click();
}

describe("ApprovalToolbar", () => {
  beforeEach(() => render());

  it("turns the toolbar on: cookie, notice class, and link text", async () => {
    const { CStorage } = await load();
    expect(CStorage.Posts.JanitorToolbar).toBe(false);

    click();
    expect(CStorage.Posts.JanitorToolbar).toBe(true);
    expect(document.cookie).toContain("janitor_toolbar=1");
    expect($("#pending-approval-notice").hasClass("enabled")).toBe(true);
    expect($("#janitor-toolbar-toggle").text()).toBe("Approvals: On");
  });

  it("turns the toolbar back off", async () => {
    document.cookie = "janitor_toolbar=1; path=/";
    render({ enabled: true });
    const { CStorage } = await load();
    expect(CStorage.Posts.JanitorToolbar).toBe(true);

    click();
    expect(CStorage.Posts.JanitorToolbar).toBe(false);
    expect($("#pending-approval-notice").hasClass("enabled")).toBe(false);
    expect($("#janitor-toolbar-toggle").text()).toBe("Approvals: Off");
  });

  it("syncs the DOM to the cookie state rather than blindly toggling", async () => {
    // Server rendered the link as "On" but the cookie says off
    render({ enabled: true });
    const { ApprovalToolbar } = await load();
    click();
    expect(ApprovalToolbar.instance.visible).toBe(true);
    expect($("#pending-approval-notice").hasClass("enabled")).toBe(true);
  });

  it("does nothing when the toggle is not rendered", async () => {
    render({ withToggle: false });
    const { ApprovalToolbar } = await load();
    expect(ApprovalToolbar.instance.visible).toBe(false);
  });
});
