import { describe, expect, it, vi } from "vitest";
import MobileTabs from "@/components/MobileTabs";

function render (): HTMLElement {
  document.body.innerHTML = `
    <div class="mobile-tabs" role="tablist">
      <button role="tab" data-tab="one" aria-controls="panel-one" aria-selected="true" tabindex="0">One</button>
      <button role="tab" data-tab="two" aria-controls="panel-two" aria-selected="false" tabindex="-1">Two</button>
      <button role="tab" data-tab="three" aria-controls="panel-three" aria-selected="false" tabindex="-1">Three</button>
    </div>
    <div id="panel-one" data-mobile-tab-panel data-active></div>
    <div id="panel-two" data-mobile-tab-panel></div>
    <div id="panel-three" data-mobile-tab-panel></div>`;
  return document.querySelector<HTMLElement>(".mobile-tabs");
}

const tab = (key: string) => document.querySelector<HTMLButtonElement>(`button[data-tab="${key}"]`);
const panel = (key: string) => document.getElementById(`panel-${key}`);
const press = (key: string) => tab("one").parentElement.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true }));

describe("MobileTabs", () => {
  it("reads the initial state from the markup", () => {
    expect(MobileTabs.init(render()).active).toBe("one");
  });

  it("switches tabs and panels on click", () => {
    const tabs = MobileTabs.init(render());

    tab("two").click();
    expect(tabs.active).toBe("two");
    expect(tab("two").getAttribute("aria-selected")).toBe("true");
    expect(tab("two").tabIndex).toBe(0);
    expect(tab("one").getAttribute("aria-selected")).toBe("false");
    expect(tab("one").tabIndex).toBe(-1);
    expect(panel("two").hasAttribute("data-active")).toBe(true);
    expect(panel("one").hasAttribute("data-active")).toBe(false);
  });

  it("ignores unknown keys", () => {
    const tabs = MobileTabs.init(render());
    expect(tabs.switchTo("bogus")).toBe(false);
    expect(tabs.active).toBe("one");
  });

  it("notifies listeners only on change", () => {
    const listener = vi.fn();
    const tabs = MobileTabs.init(render()).onChange(listener);

    tabs.switchTo("one");
    expect(listener).not.toHaveBeenCalled();
    tabs.switchTo("three");
    expect(listener).toHaveBeenCalledExactlyOnceWith("three");
  });

  it("supports arrow, home and end keys", () => {
    const tabs = MobileTabs.init(render());

    press("ArrowLeft");
    expect(tabs.active).toBe("three");
    expect(document.activeElement).toBe(tab("three"));
    press("ArrowRight");
    expect(tabs.active).toBe("one");
    press("End");
    expect(tabs.active).toBe("three");
    press("Home");
    expect(tabs.active).toBe("one");
  });

  it("returns the same instance for the same element", () => {
    const root = render();
    expect(MobileTabs.init(root)).toBe(MobileTabs.init(root));
    expect(MobileTabs.initAll()).toEqual([MobileTabs.init(root)]);
  });
});
