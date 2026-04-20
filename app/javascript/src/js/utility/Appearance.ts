import LStorage from "./storage";

const Values = {
  "Theme": ["Main", "Extra", "Palette", "Font", "StickyHeader", "Navbar", "Gestures", "Logo"],
  "Posts": ["WikiExcerpt", "StickySearch"],
  "Site": ["Events"],
};

const Appearance = {
  Theme: {},
  Posts: {},
  Site: {},
} as {
  Theme: {
    Main: string;
    Extra: string;
    Palette: string;
    Font: string;
    StickyHeader: boolean;
    Navbar: boolean;
    Gestures: boolean;
    Logo: string;
  },
  Posts: {
    WikiExcerpt: number;
    StickySearch: boolean;
  },
  Site: {
    Events: boolean;
  },
};

for (const [label, settings] of Object.entries(Values)) {
  for (const one of settings) {
    Object.defineProperty(Appearance[label], one, {
      get () { return LStorage[label][one]; },
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

export default Appearance;
