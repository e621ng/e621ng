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
      "History":      "history",
    },

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

  init () {
    if (!Page.matches("static", "keyboard-shortcuts")) return;

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
    if (User.is.privileged) buildDefs(StaticShortcuts.PrivilegedDefs);
    if (User.is.janitor) buildDefs(StaticShortcuts.JanitorDefs);

    function buildDefs (list) {
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
              default: Hotkeys.Definitions[action] === Hotkeys.Defaults[action],
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
  handleInput (element) {

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
      toggleResetButton(action);
    });

    $document.on("e6.hotkeys.keydown.bind", (_event, data) => {
      // Gracefully abort
      for (const one of data) {
        if (!StaticShortcuts.AbortKeys.includes(one)) continue;

        resetInput(element, "");
        $document.off("e6.hotkeys.keyup.bind e6.hotkeys.keydown.bind");
        Hotkeys.Definitions[action] = collectBindings(action).join("|");
        Hotkeys.rebuildKeyIndexes();
        toggleResetButton(action);

        return;
      }

      binding = Hotkeys.buildKeybindString([...data]);
      element.text(binding);
    });

    function resetInput ($input, value = null) {
      if (value == null) value = $input.attr("old") || "";
      $input
        .text(value)
        .removeAttr("ready")
        .removeAttr("old");
    }

    function collectBindings (action) {
      let allBindings = [];
      for (const one of $("button[action='" + action + "']"))
        allBindings.push(one.innerText);
      allBindings = allBindings.filter(n => n);
      return allBindings;
    }

    function toggleResetButton (action) {
      const isDefault = Hotkeys.Definitions[action] === Hotkeys.Defaults[action];
      $(`.hotkey-keys[action="${action}"]`).attr("default", isDefault);
    }
  }

  /**
   * Handle resetting a hotkey to its default value.
   * @param {JQuery<HTMLElement>} element
   */
  handleReset (element) {
    const action = element.attr("action");
    Hotkeys.Definitions[action] = Hotkeys.Defaults[action];
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
