import Page from "./utility/page";
import LStorage from "./utility/storage";

const Theme = {};

Theme.initialize_selector = function () {
  if (!LStorage.isAvailable()) {
    // This is here purely because it was in the old code.
    // All browsers made after 2008 should support this.
    $("#no_save_warning").show();
    return false;
  }

  console.log("init");

  const $body = $(document.body);
  for (const one of ["Main", "Extra", "Palette", "Navbar", "Gestures"]) {
    const id = one.toLowerCase();
    $("#theme_" + id)
      .val(LStorage.Theme[one] + "")
      .on("change", (event) => {
        const data = event.target.value;
        LStorage.Theme[one] = data;
        $body.attr("data-th-" + id, data);
      });
  }
};

$(() => {
  if (Page.matches("static", "theme"))
    Theme.initialize_selector();
});

export default Theme;
