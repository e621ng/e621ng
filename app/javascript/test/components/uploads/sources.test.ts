import { mount, VueWrapper } from "@vue/test-utils";
import { afterEach, describe, expect, it } from "vitest";
import { nextTick, reactive } from "vue";
import Sources from "@/pages/uploads/new/sources.vue";

const wrappers: VueWrapper[] = [];
afterEach(() => {
  for (const wrapper of wrappers.splice(0)) wrapper.unmount();
});

// The real parent passes a reactive data() array that the component mutates
// in place; a plain array would not track splices.
function make (overrides: { sources?: string[], maxSources?: number, showErrors?: boolean } = {}) {
  const props = {
    sources: reactive(overrides.sources ?? [""]),
    maxSources: overrides.maxSources ?? 10,
    showErrors: overrides.showErrors ?? true,
  };
  const wrapper = mount(Sources, { props, attachTo: document.body });
  wrappers.push(wrapper);
  return { wrapper, sources: props.sources };
}

function lastEmitted (wrapper: VueWrapper, name: string): unknown {
  const events = wrapper.emitted(name);
  return events ? events[events.length - 1][0] : undefined;
}

function rowInputs (wrapper: VueWrapper) {
  return wrapper.findAll(".upload-source-row input");
}

describe("uploads/sources", () => {
  describe("missing-source warning", () => {
    it("emits true on mount when no source is filled in", () => {
      const { wrapper } = make();
      expect(lastEmitted(wrapper, "missingSourceWarning")).toBe(true);
      expect(lastEmitted(wrapper, "nonUrlSourceWarning")).toBe(false);
    });

    it("emits false once a source is entered", async () => {
      const { wrapper } = make();
      await rowInputs(wrapper)[0].setValue("https://example.com/post/1");
      expect(lastEmitted(wrapper, "missingSourceWarning")).toBe(false);
    });

    it("is suppressed by the no-source checkbox, which also hides the source list", async () => {
      const { wrapper } = make();
      await wrapper.find("#no_source").setValue(true);
      expect(lastEmitted(wrapper, "missingSourceWarning")).toBe(false);
      expect(wrapper.find(".upload-source-list").exists()).toBe(false);
    });

    it("shows the warning box only when showErrors is set", async () => {
      const shown = make().wrapper;
      expect(shown.findAll(".source_warning")[0].isVisible()).toBe(true);

      const hidden = make({ showErrors: false }).wrapper;
      expect(hidden.findAll(".source_warning")[0].isVisible()).toBe(false);
    });
  });

  describe("non-URL source warning", () => {
    it("accepts http and https URLs", () => {
      const { wrapper } = make({ sources: ["https://example.com/a", "http://example.com/b"] });
      expect(lastEmitted(wrapper, "nonUrlSourceWarning")).toBe(false);
    });

    it("warns on plain text", () => {
      const { wrapper } = make({ sources: ["not a url"] });
      expect(lastEmitted(wrapper, "nonUrlSourceWarning")).toBe(true);
    });

    it("warns on non-http protocols", () => {
      const { wrapper } = make({ sources: ["ftp://example.com/a"] });
      expect(lastEmitted(wrapper, "nonUrlSourceWarning")).toBe(true);
    });

    it("honours the dead-link '-' prefix", () => {
      const dead = make({ sources: ["-https://example.com/gone"] }).wrapper;
      expect(lastEmitted(dead, "nonUrlSourceWarning")).toBe(false);

      const bogus = make({ sources: ["-notaurl"] }).wrapper;
      expect(lastEmitted(bogus, "nonUrlSourceWarning")).toBe(true);
    });

    it("ignores empty entries", () => {
      const { wrapper } = make({ sources: ["", "https://example.com/a"] });
      expect(lastEmitted(wrapper, "nonUrlSourceWarning")).toBe(false);
    });

    it("is suppressed by the no-source checkbox", async () => {
      const { wrapper } = make({ sources: ["not a url"] });
      expect(lastEmitted(wrapper, "nonUrlSourceWarning")).toBe(true);
      await wrapper.find("#no_source").setValue(true);
      expect(lastEmitted(wrapper, "nonUrlSourceWarning")).toBe(false);
    });
  });

  describe("adding sources", () => {
    it("appends an empty source and focuses it", async () => {
      const { wrapper, sources } = make();
      await wrapper.find(".upload-source-add").trigger("click");
      await nextTick();
      expect(sources).toEqual(["", ""]);
      expect(document.activeElement).toBe(rowInputs(wrapper)[1].element);
    });

    it("hides the add button at maxSources", () => {
      const { wrapper } = make({ sources: ["a", "b"], maxSources: 2 });
      expect(wrapper.find(".upload-source-add").exists()).toBe(false);
    });

    it("hides the add button when no-source is checked", async () => {
      const { wrapper } = make();
      await wrapper.find("#no_source").setValue(true);
      expect(wrapper.find(".upload-source-add").exists()).toBe(false);
    });

    it("inserts after the current row on Enter", async () => {
      const { wrapper, sources } = make({ sources: ["https://a", "https://b"] });
      await rowInputs(wrapper)[0].trigger("keyup.enter");
      expect(sources).toEqual(["https://a", "", "https://b"]);
    });
  });

  describe("removing sources", () => {
    it("removes the clicked row", async () => {
      const { wrapper, sources } = make({ sources: ["https://a", "https://b"] });
      await wrapper.findAll(".upload-source-row button")[0].trigger("click");
      expect(sources).toEqual(["https://b"]);
    });

    it("refills with a single empty source when the last row is removed", async () => {
      const { wrapper, sources } = make({ sources: ["https://a"] });
      await wrapper.find(".upload-source-row button").trigger("click");
      expect(sources).toEqual([""]);
    });
  });

  describe("pasting", () => {
    function paste (wrapper: VueWrapper, index: number, text: string) {
      return rowInputs(wrapper)[index].trigger("paste", {
        clipboardData: { getData: () => text },
      });
    }

    it("splits multi-line pastes into one source per line, trimming blanks", async () => {
      const { wrapper, sources } = make();
      await paste(wrapper, 0, "https://a\n  https://b  \n\nhttps://c");
      expect(sources).toEqual(["https://a", "https://b", "https://c"]);
    });

    it("caps multi-line pastes at maxSources", async () => {
      const { wrapper, sources } = make({ maxSources: 2 });
      await paste(wrapper, 0, "https://a\nhttps://b\nhttps://c");
      expect(sources).toEqual(["https://a", "https://b"]);
    });

    it("replaces entries starting at the pasted row", async () => {
      const { wrapper, sources } = make({ sources: ["https://keep", "https://old"] });
      await paste(wrapper, 1, "https://a\nhttps://b");
      expect(sources).toEqual(["https://keep", "https://a", "https://b"]);
    });

    it("leaves single-line pastes to vanilla input behaviour", async () => {
      const { wrapper, sources } = make();
      await paste(wrapper, 0, "https://only-one");
      expect(sources).toEqual([""]);
    });
  });

  describe("keyboard navigation", () => {
    it("wraps focus around both ends of the list", async () => {
      const { wrapper } = make({ sources: ["https://a", "https://b"] });
      const inputs = rowInputs(wrapper);

      await inputs[1].trigger("keyup.down");
      expect(document.activeElement).toBe(inputs[0].element);

      await inputs[0].trigger("keyup.up");
      expect(document.activeElement).toBe(inputs[1].element);
    });
  });

  it("writes typed values back into the sources array", async () => {
    const { wrapper, sources } = make();
    await rowInputs(wrapper)[0].setValue("https://example.com/typed");
    expect(sources[0]).toBe("https://example.com/typed");
  });
});
