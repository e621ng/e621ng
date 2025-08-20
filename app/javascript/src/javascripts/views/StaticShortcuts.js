import Hotkeys from "../hotkeys";
import User from "../models/User";
import Page from "../utility/page";

export default class StaticShortcuts {

  static AbortKeys = ["Escape", "|"];

  static Definitions = {
    "General": {
      "Search":       "search",
      "Edit":         "edit",
      "Previous":     "prev",
      "Next":         "next",
      "Scroll Up":    "scroll-up",
      "Scroll Down":  "scroll-down",
      "Mark as Read": "mark-read",
    },

    "Posts": {
      "Vote Up":          "upvote",
      "Vote Down":        "downvote",
      "Add Favorite":     "favorite-add",
      "Remove Favorite":  "favorite-del",
      "Toggle Favorite":  "favorite",
      "Add Note":         "note",
      "Random":           "random",
      "Resize":           "resize",
      "Edit Inline":      "edit-d",
    },
  };

  static PrivilegedDefs = {
    "Tag Scripts": {
      "Script 1":     "tag-script-1",
      "Script 2":     "tag-script-2",
      "Script 3":     "tag-script-3",
      "Script 4":     "tag-script-4",
      "Script 5":     "tag-script-5",
      "Script 6":     "tag-script-6",
      "Script 7":     "tag-script-7",
      "Script 8":     "tag-script-8",
      "Script 9":     "tag-script-9",
    },
  };

  static JanitorDefs = {
    "Approval": {
      "Approve":        "approve",
      "Approve & Prev": "approve-prev",
      "Approve & Next": "approve-next",
    },
  };

  init() {
    if (!Page.matches("static", "keyboard-shortcuts")) return;

    this.build();

    $("#hotkeys-wrapper").on("click", "button", (event) => {
      this.handleInput($(event.currentTarget));
    });
  }

  /** Build the hotkey rebinding UI. */
  build() {
    const wrapper = $("#hotkeys-wrapper");

    buildDefs(StaticShortcuts.Definitions);
    if (User.is.privileged) buildDefs(StaticShortcuts.PrivilegedDefs);
    if (User.is.janitor) buildDefs(StaticShortcuts.JanitorDefs);

    function buildDefs(list) {
      for (const [category, definitions] of Object.entries(list)) {
        $("<h3>").text(category).appendTo(wrapper);

        for (const [name, action] of Object.entries(definitions)) {
          $("<span class='hotkey-title'>").text(name).appendTo(wrapper);
          const keyGroup = $("<div class='hotkey-keys'>").appendTo(wrapper);
          for (const one of Hotkeys.getKeys(action))
            $("<button>")
              .attr({
                "action": action,
                "title": one,
              })
              .text(one)
              .appendTo(keyGroup);
        }
      }
    }
  }


  /**
   * Handle hotkey rebinding.
   * @param {JQuery<HTMLElement>} element 
   */
  handleInput(element) {

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
      Hotkeys.Definitions[action] = collectBindings(action).join("|");
      Hotkeys.rebuildKeyIndexes();
    });

    $document.on("e6.hotkeys.keydown.bind", (_event, data) => {
      // Gracefully abort
      for (const one of data) {
        if (!StaticShortcuts.AbortKeys.includes(one)) continue;

        resetInput(element, "");
        $document.off("e6.hotkeys.keyup.bind e6.hotkeys.keydown.bind");
        Hotkeys.Definitions[action] = collectBindings(action).join("|");
        Hotkeys.rebuildKeyIndexes();

        return;
      }

      binding = Hotkeys.buildKeybindString([...data]);
      element.text(binding);
    });

    function resetInput($input, value = null) {
      if (value == null) value = $input.attr("old") || "";
      $input
        .text(value)
        .removeAttr("ready")
        .removeAttr("old");
    }

    function collectBindings(action) {
      let allBindings = [];
      for (const one of $("button[action='" + action + "']"))
        allBindings.push(one.innerText);
      allBindings = allBindings.filter(n => n);
      return allBindings;
    }
  }

}

$(() => {
  (new StaticShortcuts()).init();
});
