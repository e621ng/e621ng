import { describe, expect, it } from "vitest";
import SearchFilters from "@/pages/posts/SearchFilters";

function setup (initialQuery = "") {
  document.body.innerHTML = `
    <div class="post-search"><textarea name="tags">${initialQuery}</textarea></div>
    <div id="advanced-search-container">
      <div class="ssc-body stm-toggle" id="media-body">
        <input type="checkbox" id="ssc-media-image" name="advanced-search-media" value="i">
        <label for="ssc-media-image">Image</label>
        <input type="checkbox" id="ssc-media-animation" name="advanced-search-media" value="a">
        <label for="ssc-media-animation">Animation</label>
        <input type="checkbox" id="ssc-media-video" name="advanced-search-media" value="v">
        <label for="ssc-media-video">Video</label>
        <input type="checkbox" id="ssc-media-flash" name="advanced-search-media" value="f">
        <label for="ssc-media-flash">Flash</label>
      </div>
      <div class="ssc-body" id="sound-body">
        <div class="ssc-sound-toggle">
          <input type="checkbox" id="ssc-sound-no" name="advanced-search-sound" value="no_sound">
          <label for="ssc-sound-no">No sound</label>
          <input type="checkbox" id="ssc-sound-yes" name="advanced-search-sound" value="sound">
          <label for="ssc-sound-yes">Sound</label>
          <input type="checkbox" id="ssc-sound-warning" name="advanced-search-sound" value="sound_warning" hidden>
          <label for="ssc-sound-warning" hidden>Sound warning</label>
        </div>
      </div>
    </div>
  `;

  const $textarea = $("textarea[name=tags]") as JQuery<HTMLTextAreaElement>;
  const $controls = $("#advanced-search-container") as JQuery<HTMLDivElement>;
  new SearchFilters($textarea, $controls);

  return {
    textarea: $textarea.get(0) as HTMLTextAreaElement,
    body: document.querySelector("#media-body") as HTMLElement,
    checkbox: (value: string) => document.querySelector(`input[name='advanced-search-media'][value='${value}']`) as HTMLInputElement,
    sound: (value: string) => document.querySelector(`input[name='advanced-search-sound'][value='${value}']`) as HTMLInputElement,
    soundLabel: (value: string) => {
      const input = document.querySelector(`input[name='advanced-search-sound'][value='${value}']`) as HTMLInputElement;
      return input.nextElementSibling as HTMLLabelElement;
    },
  };
}

function click (checkbox: HTMLInputElement, checked: boolean) {
  checkbox.checked = checked;
  checkbox.dispatchEvent(new Event("change", { bubbles: true }));
}

describe("SearchFilters - media type DOM sync", () => {
  it("initial sync: unrestricted query checks all four, no custom marker", () => {
    const { checkbox, body } = setup("solo");
    for (const value of ["i", "a", "v", "f"]) {
      expect(checkbox(value).checked).toBe(true);
      expect(checkbox(value).indeterminate).toBe(false);
    }
    expect(body.classList.contains("ssc-media-custom")).toBe(false);
  });

  it("selecting Video only (unchecking the other three) updates the textarea and checkbox states", () => {
    const { textarea, checkbox } = setup("solo");
    // Starting from the unrestricted state (all four checked), a user selecting
    // "Video only" unchecks Image, Animation, and Flash, leaving Video checked.
    checkbox("i").checked = false;
    checkbox("a").checked = false;
    checkbox("f").checked = false;
    click(checkbox("v"), true);

    expect(textarea.value).toBe("solo video");
    expect(checkbox("v").checked).toBe(true);
    expect(checkbox("i").checked).toBe(false);
    expect(checkbox("a").checked).toBe(false);
    expect(checkbox("f").checked).toBe(false);
  });

  it("unchecking the last checked box clears the query but leaves all four unchecked (mirrors Rating)", () => {
    const { textarea, checkbox } = setup("solo video");
    // Only Video is checked initially (per the "solo video" query); uncheck it.
    expect(checkbox("v").checked).toBe(true);
    click(checkbox("v"), false);

    expect(textarea.value).toBe("solo");
    // The query is unrestricted (no media term), but we must not fight the user's own
    // action by re-checking boxes they just unchecked.
    for (const value of ["i", "a", "v", "f"]) {
      expect(checkbox(value).checked).toBe(false);
      expect(checkbox(value).indeterminate).toBe(false);
    }
  });

  it("checking all four explicitly clears the owned selection, resyncing to the remaining custom state", () => {
    const { textarea, checkbox, body } = setup("animated_gif video");
    // Start from a custom+owned state, then explicitly check every box (checked.length
    // is 4, not 0, so this always takes the normal post-write resync path).
    checkbox("i").checked = true;
    checkbox("a").checked = true;
    checkbox("f").checked = true;
    click(checkbox("v"), true);

    // The owned "video" term is gone, but animated_gif remains — nothing is ownable any
    // more, so this correctly resyncs to the same "custom, nothing ownable" indeterminate
    // representation as unchecking the last box would (see the test below), not "checked".
    expect(textarea.value).toBe("animated_gif");
    for (const value of ["i", "a", "v", "f"]) {
      expect(checkbox(value).indeterminate).toBe(true);
      expect(checkbox(value).checked).toBe(false);
    }
    expect(body.classList.contains("ssc-media-custom")).toBe(true);
  });

  it("checking all four explicitly with no custom content clears the query and shows a plain checked state", () => {
    const { textarea, checkbox, body } = setup("solo video");
    checkbox("i").checked = true;
    checkbox("a").checked = true;
    checkbox("f").checked = true;
    click(checkbox("v"), true);

    expect(textarea.value).toBe("solo");
    for (const value of ["i", "a", "v", "f"]) {
      expect(checkbox(value).checked).toBe(true);
      expect(checkbox(value).indeterminate).toBe(false);
    }
    expect(body.classList.contains("ssc-media-custom")).toBe(false);
  });

  it("a later independent query resync (not a checkbox click) restores all four checked for an unrestricted query", () => {
    const { textarea, checkbox } = setup("solo video");
    click(checkbox("v"), false);
    for (const value of ["i", "a", "v", "f"]) expect(checkbox(value).checked).toBe(false);

    // An independent edit to the textarea (not driven by the media checkboxes) triggers
    // the normal, un-gated resync — this is the same basic all-checked/all-unchecked
    // ambiguity Rating has, resolved the same way: the next parse of the (identical,
    // still-unrestricted) query renders as the default "all checked" representation.
    textarea.value = "solo ";
    textarea.dispatchEvent(new Event("input", { bubbles: true }));

    for (const value of ["i", "a", "v", "f"]) {
      expect(checkbox(value).checked).toBe(true);
      expect(checkbox(value).indeterminate).toBe(false);
    }
  });

  it("unchecking the last box when custom content remains syncs to the custom-only representation", () => {
    const { textarea, checkbox } = setup("animated_gif video");
    expect(checkbox("v").checked).toBe(true);
    click(checkbox("v"), false);

    // animated_gif alone is left in the query — nothing ownable, so this must NOT take
    // the "preserve as unchecked, skip resync" shortcut; it must resync to indeterminate.
    expect(textarea.value).toBe("animated_gif");
    for (const value of ["i", "a", "v", "f"]) {
      expect(checkbox(value).indeterminate).toBe(true);
      expect(checkbox(value).checked).toBe(false);
    }
  });

  it("a custom expression with nothing ownable renders all four indeterminate, unchecked", () => {
    const { checkbox, body } = setup("animated_gif");
    for (const value of ["i", "a", "v", "f"]) {
      expect(checkbox(value).indeterminate).toBe(true);
      expect(checkbox(value).checked).toBe(false);
    }
    expect(body.classList.contains("ssc-media-custom")).toBe(true);
  });

  it("a custom expression alongside an owned selection keeps that selection checked normally, plus a marker", () => {
    const { checkbox, body } = setup("animated_gif video");
    expect(checkbox("v").checked).toBe(true);
    expect(checkbox("v").indeterminate).toBe(false);
    expect(checkbox("i").checked).toBe(false);
    expect(checkbox("i").indeterminate).toBe(false);
    expect(body.classList.contains("ssc-media-custom")).toBe(true);
  });

  it("clicking an additional checkbox while a custom+owned selection is checked combines additively", () => {
    const { textarea, checkbox } = setup("animated_gif video");
    expect(checkbox("v").checked).toBe(true);

    // Ordinary DOM click semantics: checking Flash leaves Video checked too.
    click(checkbox("f"), true);

    expect(textarea.value).toBe("animated_gif ( ~video ~flash )");
    expect(checkbox("v").checked).toBe(true);
    expect(checkbox("f").checked).toBe(true);
  });
});

describe("SearchFilters - sound DOM sync", () => {
  it("initial state: only No sound + Sound visible, neither checked, Warning hidden", () => {
    const { sound, soundLabel } = setup("solo");
    expect(sound("no_sound").checked).toBe(false);
    expect(sound("sound").checked).toBe(false);
    expect(sound("sound_warning").checked).toBe(false);
    expect(sound("sound_warning").hidden).toBe(true);
    expect(soundLabel("sound_warning").hidden).toBe(true);
  });

  it("clicking Sound checks Sound + Warning by default and reveals Warning", () => {
    const { textarea, sound, soundLabel } = setup("solo");
    click(sound("sound"), true);

    expect(textarea.value).toBe("solo sound");
    expect(sound("sound").checked).toBe(true);
    expect(sound("sound_warning").checked).toBe(true);
    expect(sound("sound_warning").hidden).toBe(false);
    expect(soundLabel("sound_warning").hidden).toBe(false);
  });

  it("unchecking Warning from both-checked leaves Sound only", () => {
    const { textarea, sound } = setup("solo sound");
    expect(sound("sound").checked).toBe(true);
    expect(sound("sound_warning").checked).toBe(true);

    click(sound("sound_warning"), false);

    expect(textarea.value).toBe("solo sound -sound_warning");
    expect(sound("sound").checked).toBe(true);
    expect(sound("sound_warning").checked).toBe(false);
    expect(sound("sound_warning").hidden).toBe(false);
  });

  it("unchecking Sound from both-checked leaves Warning only, still expanded", () => {
    const { textarea, sound } = setup("solo sound");
    click(sound("sound"), false);

    expect(textarea.value).toBe("solo sound_warning");
    expect(sound("sound").checked).toBe(false);
    expect(sound("sound_warning").checked).toBe(true);
    expect(sound("sound_warning").hidden).toBe(false);
  });

  it("removing the last active sound option clears the query and collapses Warning", () => {
    const { textarea, sound, soundLabel } = setup("solo sound -sound_warning");
    expect(sound("sound").checked).toBe(true);
    expect(sound("sound_warning").checked).toBe(false);

    click(sound("sound"), false);

    expect(textarea.value).toBe("solo");
    expect(sound("no_sound").checked).toBe(false);
    expect(sound("sound").checked).toBe(false);
    expect(sound("sound_warning").checked).toBe(false);
    expect(sound("sound_warning").hidden).toBe(true);
    expect(soundLabel("sound_warning").hidden).toBe(true);
  });

  it("removing the last active option from warning-only also collapses cleanly", () => {
    const { textarea, sound } = setup("solo sound_warning");
    expect(sound("sound_warning").checked).toBe(true);

    click(sound("sound_warning"), false);

    expect(textarea.value).toBe("solo");
    expect(sound("sound").checked).toBe(false);
    expect(sound("sound_warning").checked).toBe(false);
    expect(sound("sound_warning").hidden).toBe(true);
  });

  it("clicking No sound while expanded clears Sound/Warning and collapses", () => {
    const { textarea, sound, soundLabel } = setup("solo sound");
    expect(sound("sound").checked).toBe(true);
    expect(sound("sound_warning").checked).toBe(true);

    click(sound("no_sound"), true);

    expect(textarea.value).toBe("solo no_sound");
    expect(sound("no_sound").checked).toBe(true);
    expect(sound("sound").checked).toBe(false);
    expect(sound("sound_warning").checked).toBe(false);
    expect(sound("sound_warning").hidden).toBe(true);
    expect(soundLabel("sound_warning").hidden).toBe(true);
  });

  it("clicking Sound while No sound is active clears No sound and expands to Sound + Warning", () => {
    const { textarea, sound } = setup("solo no_sound");
    expect(sound("no_sound").checked).toBe(true);

    click(sound("sound"), true);

    expect(textarea.value).toBe("solo sound");
    expect(sound("no_sound").checked).toBe(false);
    expect(sound("sound").checked).toBe(true);
    expect(sound("sound_warning").checked).toBe(true);
    expect(sound("sound_warning").hidden).toBe(false);
  });

  it("checking Sound warning from Sound-only checks both, staying expanded", () => {
    const { textarea, sound } = setup("solo sound -sound_warning");
    expect(sound("sound").checked).toBe(true);
    expect(sound("sound_warning").checked).toBe(false);

    click(sound("sound_warning"), true);

    expect(textarea.value).toBe("solo sound");
    expect(sound("sound").checked).toBe(true);
    expect(sound("sound_warning").checked).toBe(true);
  });

  it("checking Sound from Warning-only checks both", () => {
    const { textarea, sound } = setup("solo sound_warning");
    expect(sound("sound_warning").checked).toBe(true);
    expect(sound("sound").checked).toBe(false);

    click(sound("sound"), true);

    expect(textarea.value).toBe("solo sound");
    expect(sound("sound").checked).toBe(true);
    expect(sound("sound_warning").checked).toBe(true);
  });

  it("manually typing each canonical form updates the UI correctly", () => {
    const { textarea, sound } = setup("solo");

    const assertState = (noSound: boolean, hasSound: boolean, hasWarning: boolean, expandedVisible: boolean) => {
      expect(sound("no_sound").checked).toBe(noSound);
      expect(sound("sound").checked).toBe(hasSound);
      expect(sound("sound_warning").checked).toBe(hasWarning);
      expect(sound("sound_warning").hidden).toBe(!expandedVisible);
    };

    const type = (value: string) => {
      textarea.value = value;
      textarea.dispatchEvent(new Event("input", { bubbles: true }));
    };

    type("solo no_sound");
    assertState(true, false, false, false);

    type("solo sound");
    assertState(false, true, true, true);

    type("solo sound -sound_warning");
    assertState(false, true, false, true);

    type("solo sound_warning");
    assertState(false, false, true, true);

    type("solo");
    assertState(false, false, false, false);
  });
});
