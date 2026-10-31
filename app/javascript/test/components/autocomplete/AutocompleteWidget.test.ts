import { describe, expect, it } from "vitest";
import AutocompleteWidget from "@/components/autocomplete/AutocompleteWidget";
import Provider from "@/components/autocomplete/Provider";

class StubProvider extends Provider {
  public async search () { return []; }
}

function dropdown (): HTMLElement {
  return document.querySelector<HTMLElement>(".ui-autocomplete-dropdown:last-of-type");
}

describe("AutocompleteWidget", () => {
  describe("dialog:move", () => {
    function build () {
      const input = document.createElement("input");
      document.body.appendChild(input);

      let rect = { left: 100, bottom: 50, width: 200 };
      input.getBoundingClientRect = () => rect as DOMRect;

      const widget = new AutocompleteWidget(input, new StubProvider());
      return { widget, moveInput: (next: typeof rect) => { rect = next; } };
    }

    it("follows the input when a dialog moves", () => {
      const { widget, moveInput } = build();
      widget.isOpen = true;
      expect(dropdown().style.left).toBe("101px");
      expect(dropdown().style.top).toBe("50px");

      moveInput({ left: 300, bottom: 250, width: 200 });
      window.dispatchEvent(new Event("dialog:move"));
      expect(dropdown().style.left).toBe("301px");
      expect(dropdown().style.top).toBe("250px");

      widget.destroy();
    });

    it("leaves closed dropdowns alone", () => {
      const { widget, moveInput } = build();
      widget.isOpen = true;
      widget.isOpen = false;

      moveInput({ left: 300, bottom: 250, width: 200 });
      window.dispatchEvent(new Event("dialog:move"));
      expect(dropdown().style.left).toBe("101px");

      widget.destroy();
    });
  });
});
