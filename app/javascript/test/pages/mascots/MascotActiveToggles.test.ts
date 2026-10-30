import { beforeEach, describe, expect, it, vi } from "vitest";
import { tick } from "../../helpers";

const { request, errorMessage, alert } = vi.hoisted(() => ({
  request: vi.fn(),
  errorMessage: vi.fn(),
  alert: vi.fn(),
}));

vi.mock("@/utility/HTTP", () => ({ default: { request, errorMessage } }));
vi.mock("@/utility/Toast", () => ({ default: { alert } }));

// Mirrors the admin "Active" cell in mascots/index.html.erb
function row (id: number, active: boolean): string {
  return `
    <tr><td>
      <button type="button" class="st-button mascot-active-toggle" data-mascot-id="${id}" aria-pressed="${active}">
        <svg></svg>
        <span class="mascot-active-on">Active</span>
        <span class="mascot-active-off">Inactive</span>
      </button>
    </td></tr>`;
}

function mount (rows: string): void {
  document.body.innerHTML = `<div id="c-mascots"><table><tbody>${rows}</tbody></table><span id="outside">x</span></div>`;
}

async function boot () {
  const MascotActiveToggles = (await import("@/pages/mascots/MascotActiveToggles")).default;
  return MascotActiveToggles.instance;
}

const button = (id: number) => document.querySelector<HTMLButtonElement>(`button[data-mascot-id="${id}"]`)!;
const sentActive = (call = 0) => (request.mock.calls[call][1].body as URLSearchParams).get("mascot[active]");

describe("MascotActiveToggles", () => {
  beforeEach(() => {
    request.mockReset();
    errorMessage.mockReset();
    alert.mockReset();
  });

  it("does nothing outside the mascots page", async () => {
    document.body.innerHTML = row(1, true);
    await boot();
    button(1).click();
    expect(request).not.toHaveBeenCalled();
  });

  it.each([
    [true, "false"],
    [false, "true"],
  ])("sends the inverse state (active=%s) and flips the button on success", async (active, next) => {
    mount(row(3, active));
    request.mockResolvedValue({ ok: true });
    await boot();

    button(3).click();
    await tick();

    expect(request).toHaveBeenCalledOnce();
    expect(request.mock.calls[0][0]).toBe("/mascots/3.json");
    expect(request.mock.calls[0][1].method).toBe("PATCH");
    expect(sentActive()).toBe(next);
    expect(button(3).getAttribute("aria-pressed")).toBe(next);
    expect(button(3).disabled).toBe(false);
    expect(button(3).hasAttribute("aria-busy")).toBe(false);
  });

  it("only affects the clicked mascot", async () => {
    mount(row(1, true) + row(2, true));
    request.mockResolvedValue({ ok: true });
    await boot();

    button(2).click();
    await tick();

    expect(button(1).getAttribute("aria-pressed")).toBe("true");
    expect(button(2).getAttribute("aria-pressed")).toBe("false");
  });

  it("handles clicks on the button's children", async () => {
    mount(row(1, true));
    request.mockResolvedValue({ ok: true });
    await boot();

    button(1).querySelector("span")!.click();
    await tick();

    expect(request).toHaveBeenCalledOnce();
  });

  it("ignores clicks outside a toggle", async () => {
    mount(row(1, true));
    await boot();
    document.getElementById("outside")!.click();
    expect(request).not.toHaveBeenCalled();
  });

  it("locks the button while the request is in flight", async () => {
    mount(row(1, true));
    let resolve!: (value: unknown) => void;
    request.mockReturnValue(new Promise((r) => { resolve = r; }));
    await boot();

    button(1).click();
    expect(button(1).disabled).toBe(true);
    expect(button(1).getAttribute("aria-busy")).toBe("true");

    // A disabled button swallows real clicks; call through directly to cover the guard too
    button(1).click();
    void (await boot()).toggle(button(1));
    expect(request).toHaveBeenCalledOnce();

    resolve({ ok: true });
    await tick();
    expect(button(1).disabled).toBe(false);
    expect(button(1).getAttribute("aria-pressed")).toBe("false");
  });

  it("keeps the old state and alerts on an error response", async () => {
    mount(row(1, true));
    const response = { ok: false, status: 422 };
    request.mockResolvedValue(response);
    errorMessage.mockResolvedValue("Artist url must start with http:// or https://");
    await boot();

    button(1).click();
    await tick();

    expect(errorMessage).toHaveBeenCalledWith(response);
    expect(alert).toHaveBeenCalledWith("Artist url must start with http:// or https://");
    expect(button(1).getAttribute("aria-pressed")).toBe("true");
    expect(button(1).disabled).toBe(false);
  });

  it("keeps the old state and alerts on a network error", async () => {
    mount(row(1, false));
    request.mockRejectedValue(new TypeError("Failed to fetch"));
    await boot();

    button(1).click();
    await tick();

    expect(alert).toHaveBeenCalledWith("Failed to update mascot");
    expect(button(1).getAttribute("aria-pressed")).toBe("false");
    expect(button(1).disabled).toBe(false);
  });
});
