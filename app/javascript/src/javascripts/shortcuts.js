import Utility from "./utility";

let Shortcuts = {};
Shortcuts.disabled = false;

Shortcuts.initialize = function () {
  Shortcuts.keydown("s", "scroll_down", Shortcuts.nav_scroll_down);
  Shortcuts.keydown("w", "scroll_up", Shortcuts.nav_scroll_up);
  Shortcuts.initialize_data_shortcuts();
};

// Bind keyboard shortcuts to links that have a `data-shortcut="..."` attribute. If multiple links have the
// same shortcut, then only the first link will be triggered by the shortcut.
Shortcuts.initialize_data_shortcuts = function () {
  $(document).off("keydown.danbooru.shortcut");

  $("[data-shortcut]").each((_i, element) => {
    const $e = $(element);
    const id = $e.attr("id");
    const keys = $e.attr("data-shortcut");
    const namespace = `shortcut.${id}`;

    if (Utility.meta("enable-js-navigation") === "true") {
      $e.attr("title", `Shortcut is ${keys.split(/\s+/).join(" or ")}`);
    } else {
      $e.attr("title", "Shortcuts are disabled. Enable them in your user settings.");
    }

    Shortcuts.keydown(keys, namespace, event => {
      const e = $(`[data-shortcut="${keys}"]`).get(0);
      if ($e.data("disabled")) return;
      if ($e.is("input, textarea")) {
        $e.trigger("focus").selectEnd();
      } else {
        e.click();
      }

      event.preventDefault();
    });
  });
};

Shortcuts.keydown = function (keys, namespace, handler) {
  if (Utility.meta("enable-js-navigation") === "true") {
    $(document).off("keydown.danbooru." + namespace);
    $(document).on("keydown.danbooru." + namespace, null, keys, e => {
      if (Shortcuts.disabled) {
        return;
      }
      handler(e);
    });
  }
};

Shortcuts.nav_scroll_down = function () {
  window.scrollBy(0, $(window).height() * 0.15);
};

Shortcuts.nav_scroll_up = function () {
  window.scrollBy(0, $(window).height() * -0.15);
};

$(document).ready(function () {
  Shortcuts.initialize();
});

export default Shortcuts;
