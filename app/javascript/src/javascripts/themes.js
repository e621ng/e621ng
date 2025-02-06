import Page from "./utility/page";
import LStorage from "./utility/storage";

const Theme = {};

Theme.Values = ["Main", "Extra", "StickyHeader", "ForumNotif", "Palette", "Navbar", "Gestures"];

for (const one of Theme.Values) {
  Object.defineProperty(Theme, one, {
    get () { return LStorage.Theme[one]; },
    set (value) {
      // No value checking, we die like men
      LStorage.Theme[one] = value;
      $("body").attr("data-th-" + one.toLowerCase(), value);
    },
  });
}

Theme.initialize_selector = function () {
  if (!LStorage.isAvailable()) {
    // This is here purely because it was in the old code.
    // All browsers made after 2008 should support this.
    $("#no_save_warning").show();
    return false;
  }

  for (const one of Theme.Values) {
    $("#theme_" + one.toLowerCase())
      .val(LStorage.Theme[one] + "")
      .on("change", (event) => {
        const data = event.target.value;
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

  $("#wiki-excerpt-value").text(LStorage.Posts.WikiExcerpt);
  $("#wiki-excerpt-reset").on("click", () => {
    LStorage.Posts.WikiExcerpt = 1;
    $("#wiki-excerpt-value").text(LStorage.Posts.WikiExcerpt);
  });
}

$(() => {
  if (!Page.matches("static", "theme")) return;
  Theme.initialize_selector();
  Theme.initialize_buttons();
});

export default Theme;
