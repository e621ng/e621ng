import Page from "./utility/page";
import LStorage from "./utility/storage";

const Theme = {};

Theme.Values = {
  "Theme": ["Main", "Extra", "Palette", "StickyHeader", "Navbar", "Gestures", "ForumNotif"],
  "Posts": ["WikiExcerpt", "StickySearch"],
};

for (const [label, settings] of Object.entries(Theme.Values)) {
  for (const one of settings) {
    Object.defineProperty(Theme, one, {
      get () { return LStorage.Theme[one]; },
      set (value) {
        // This has the unintended side effect of setting
        // attribute values that don't exist on the body.
        LStorage[label][one] = value;
        $("body").attr("data-th-" + one.toLowerCase(), value);
      },
    });
  }
}

Theme.initialize_selector = function () {
  if (!LStorage.isAvailable()) {
    // This is here purely because it was in the old code.
    // All browsers made after 2008 should support this.
    $("#no_save_warning").show();
    return false;
  }

  for (const [label, settings] of Object.entries(Theme.Values)) {
    for (const one of settings)
      $(`#${label}_${one}`)
        .val(LStorage[label][one] + "")
        .on("change", (event) => {
          const data = event.target.value;
          console.log("change", one, data);
          Theme[one] = data;
        });
  }
};

Theme.initialize_buttons = function () {
  if (!LStorage.isAvailable()) return;

  $("#mascot-value").text(LStorage.Site.Mascot);
  $("#mascot-reset").on("click", () => {
    LStorage.Site.Mascot = 0;
    $("#mascot-value").text(LStorage.Site.Mascot);
  });
};

$(() => {
  if (!Page.matches("static", "theme")) return;
  Theme.initialize_selector();
  Theme.initialize_buttons();
});

export default Theme;
