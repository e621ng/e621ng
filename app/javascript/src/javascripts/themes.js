import Page from "./utility/page";
import LStorage from "./utility/storage";

const Theme = {};

Theme.Values = {
  "Theme": ["Main", "Extra", "Palette", "Font", "StickyHeader", "Navbar", "Gestures", "Logo"],
  "Posts": ["WikiExcerpt", "StickySearch"],
  "Site": ["Events"],
};

for (const [label, settings] of Object.entries(Theme.Values)) {
  for (const one of settings) {
    Object.defineProperty(Theme, one, {
      get () { return LStorage.Theme[one]; },
      set (value) {
        // This has the unintended side effect of setting
        // attribute values that don't exist on the body.
        LStorage[label][one] = value;
        // If we're on the static homepage, don't apply the main or extra theme
        // attributes; leave those unset so the default (hexagon) is used.
        if ($("body").is(".c-static.a-home") && (one === "Main" || one === "Extra")) return;

        // Homepage fallback to hexagon is handled in `app/views/layouts/_theme_include.html.erb`;
        // just write the attribute normally for other pages/keys.
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
          Theme[one] = data;
        });
  }
};

Theme.initialize_buttons = function () {
  if (!LStorage.isAvailable()) return;

  if (LStorage.Site.Mascot !== 0) {
    $("#mascot-state").show();
    $("#mascot-value").text(LStorage.Site.Mascot);
    $("#mascot-reset").on("click", () => {
      LStorage.Site.Mascot = 0;
      $("#mascot-state").hide();
    });
  }

  if (LStorage.Posts.Recommendations === "closed") {
    $("#recommended-state").show();
    $("#recommended-reset").on("click", () => {
      LStorage.Posts.Recommendations = "artist";
      $("#recommended-state").hide();
    });
  }
};

$(() => {
  if (!Page.matches("static", "theme")) return;
  Theme.initialize_selector();
  Theme.initialize_buttons();
});

export default Theme;
