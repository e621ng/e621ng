import Hotkeys from "@/core/hotkeys";
import HotkeysConfig from "@/core/hotkeys/HotkeysConfig";
import * as Types from "@/core/hotkeys/Types";
import E621Type from "@/interfaces/E621";

declare const E621: E621Type;

export default class StaticShortcuts {

  static AbortKeys = ["Escape", "|"];

  static Definitions = {
    "General": {
      "Search":           "search",
      "Edit":             "edit",
      "Previous":         "prev",
      "Next":             "next",
      "Scroll Up":        "scroll-up",
      "Scroll Down":      "scroll-down",
      "Mark as Read":     "mark-read",
      "History":          "history",
      "Toggle Blacklist": "blacklist",
    } as Types.HotkeyBindingsList,

    "Posts": {
      "Vote Up":          "upvote",
      "Vote Down":        "downvote",
      "Add Favorite":     "favorite-add",
      "Remove Favorite":  "favorite-del",
      "Toggle Favorite":  "favorite",
      "Random Post":      "random",
      "Add Note":         "note",
      "Toggle Notes":     "note-toggle",
      "Resize":           "resize",

      "Fullscreen":       "fullscreen",
      "Download":         "download",
      "Add to Set":       "add-to-set",
      "Add to Pool":      "add-to-pool",

      "Toggle Related":   "postrel",
      "Recommendations":  "postrec",
    } as Types.HotkeyBindingsList,

    "Reverse Image Search": {
      "IQDB":             "iqdb",
      "Google":           "ris-google",
      "SauceNAO":         "ris-saucenao",
      "Derpibooru":       "ris-derpi",
      "Yandex":           "ris-yandex",
      "FuzzySearch":      "ris-fzsearch",
      "Fluffle":          "ris-fluffle",
      "Inkbunny":         "ris-inkbunny",
    } as Types.HotkeyBindingsList,
  };

  static PrivilegedDefs = {
    "Tag Scripts": {
      "Script 1":         "tag-script-1",
      "Script 2":         "tag-script-2",
      "Script 3":         "tag-script-3",
      "Script 4":         "tag-script-4",
      "Script 5":         "tag-script-5",
      "Script 6":         "tag-script-6",
      "Script 7":         "tag-script-7",
      "Script 8":         "tag-script-8",
      "Script 9":         "tag-script-9",
    } as Types.HotkeyBindingsList,
  };

  static JanitorDefs = {
    "Approval": {
      "Approve":          "approve",
      "Approve & Prev":   "approve-prev",
      "Approve & Next":   "approve-next",
    } as Types.HotkeyBindingsList,
  };

  init () {
    this.build();

    // Rebinding
    $("#hotkeys-wrapper").on("click", "button.hotkey-rebind", (event) => {
      event.preventDefault();
      const element = $(event.currentTarget);
      element.trigger("blur");

      this.handleInput(element);
      return false;
    });

    // Reset to default
    $("#hotkeys-wrapper").on("click", "button.hotkey-reset", (event) => {
      event.preventDefault();
      const element = $(event.currentTarget);
      element.trigger("blur");

      this.handleReset(element);
      return false;
    });
  }

  /** Build the hotkey rebinding UI. */
  build () {
    const wrapper = $("#hotkeys-wrapper");
    const resetIcon = $(".hotkey-reset-icon").clone().removeClass("hotkey-reset-icon");

    buildDefs(StaticShortcuts.Definitions);
    if (E621.CurrentUser.is.privileged) buildDefs(StaticShortcuts.PrivilegedDefs);
    if (E621.CurrentUser.is.janitor) buildDefs(StaticShortcuts.JanitorDefs);

    function buildDefs (list: Record<string, Types.HotkeyBindingsList>) {
      for (const [category, definitions] of Object.entries(list)) {
        $("<h3>").text(category).appendTo(wrapper);

        // Build the inputs
        for (const [name, action] of Object.entries(definitions)) {
          // Title section
          $("<span class='hotkey-title'>").text(name).appendTo(wrapper);
          const keyGroup = $("<div>")
            .addClass("hotkey-keys")
            .attr({
              action: action,
              default: HotkeysConfig.Keys[action] === HotkeysConfig.Defaults[action],
            })
            .appendTo(wrapper);

          // Key bindings
          let index = 0;
          for (const one of Hotkeys.getKeys(action))
            // Rebinding inputs
            $("<button>")
              .addClass("hotkey-rebind")
              .attr({
                action: action,
                title: one,
                index: index++,
              })
              .text(one)
              .appendTo(keyGroup);

          // Reset to default
          $("<button>")
            .addClass("hotkey-reset")
            .attr({
              action: action,
              title: "Reset the binding to the default value",
            })
            .append(resetIcon.clone())
            .appendTo(keyGroup);
        }
      }
    }
  }


  /**
   * Handle hotkey rebinding.
   * @param {JQuery<HTMLElement>} element
   */
  handleInput (element: JQuery<HTMLElement>) {

    // Clean up any other active rebinding inputs
    const $document = $(document);
    $document.off("e6.hotkeys.keyup.bind e6.hotkeys.keydown.bind");
    for (const one of $("button[ready='true']")) resetInput($(one));

    const oldValue = element.text();
    const action = element.attr("action");

    // "Ready for input" state
    element
      .text("...")
      .attr({
        ready: true,
        old: oldValue,
      });

    // Listen to hotkey inputs
    let binding = "";
    $document.on("e6.hotkeys.keyup.bind", (_event, data) => {
      if (data.size !== 0) return;

      resetInput(element, binding);
      $document.off("e6.hotkeys.keyup.bind e6.hotkeys.keydown.bind");
      HotkeysConfig.Keys[action] = collectBindings(action).join("|");
      Hotkeys.rebuildKeyIndexes();
      toggleResetButton(action);
    });

    $document.on("e6.hotkeys.keydown.bind", (_event, data) => {
      // Gracefully abort
      for (const one of data) {
        if (!StaticShortcuts.AbortKeys.includes(one)) continue;

        resetInput(element, "");
        $document.off("e6.hotkeys.keyup.bind e6.hotkeys.keydown.bind");
        HotkeysConfig.Keys[action] = collectBindings(action).join("|");
        Hotkeys.rebuildKeyIndexes();
        toggleResetButton(action);

        return;
      }

      binding = HotkeysConfig.toKeybindString([...data]);
      element.text(binding);
    });

    function resetInput ($input: JQuery<HTMLElement>, value: string | null = null) {
      if (value == null) value = $input.attr("old") || "";
      $input
        .text(value)
        .removeAttr("ready")
        .removeAttr("old");
    }

    function collectBindings (action: string): string[] {
      let allBindings = [];
      for (const one of $("button[action='" + action + "']"))
        allBindings.push(one.innerText);
      allBindings = allBindings.filter(n => n);
      return allBindings;
    }

    function toggleResetButton (action: string) {
      const isDefault = HotkeysConfig.Keys[action] === HotkeysConfig.Defaults[action];
      $(`.hotkey-keys[action="${action}"]`).attr("default", isDefault + "");
    }
  }

  /**
   * Handle resetting a hotkey to its default value.
   * @param {JQuery<HTMLElement>} element
   */
  handleReset (element: JQuery<HTMLElement>) {
    const action = element.attr("action") as Types.HotkeyAction;
    if (!(action in HotkeysConfig.Defaults)) return;

    HotkeysConfig.Keys[action] = HotkeysConfig.Defaults[action];
    Hotkeys.rebuildKeyIndexes();
    $(`.hotkey-keys[action="${action}"]`).attr("default", "true");

    let index = 0;
    for (const one of Hotkeys.getKeys(action))
      $(`.hotkey-rebind[action="${action}"][index="${index++}"]`).text(one);
  }

}

$(() => {
  (new StaticShortcuts()).init();
});
