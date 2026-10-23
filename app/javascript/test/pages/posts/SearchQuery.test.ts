import { describe, expect, it } from "vitest";
import SearchQuery, {
  MEDIA_ALL, MEDIA_TOKEN, RATING_TOKEN,
  SOUND_BOTH, SOUND_NO_SOUND, SOUND_NONE, SOUND_ONLY, SOUND_WARNING_ONLY,
} from "@/pages/posts/SearchQuery";

function media (raw: string) {
  const q = new SearchQuery(raw);
  return { media: q.media, mediaCustom: q.mediaCustom };
}

function sound (raw: string) {
  const q = new SearchQuery(raw);
  return { sound: q.sound, soundCustom: q.soundCustom };
}

describe("SearchQuery - rating (regression)", () => {
  it("collapses all three ratings to no metatag", () => {
    expect(new SearchQuery("solo").withRatings(["s", "q", "e"]).toString()).toBe("solo");
  });

  it("emits a single negated metatag for two active ratings", () => {
    expect(new SearchQuery("solo").withRatings(["s", "q"]).toString()).toBe("solo -rating:e");
  });

  it("round-trips every RATING_TOKEN entry", () => {
    for (const token of Object.values(RATING_TOKEN)) {
      const q = new SearchQuery(token);
      expect(RATING_TOKEN[q.ratings]).toBe(token);
    }
  });
});

describe("SearchQuery - scanTopLevelTokens fix", () => {
  it("treats a multi-word parenthesized group as one opaque token, not multiple", () => {
    // Exercised indirectly: writing a rating metatag next to a multi-word group must
    // leave the group completely intact rather than truncating or fragmenting it.
    const q = new SearchQuery("(fluffy ~canine ~feline) rating:s");
    const result = q.withRatings(["q"]).toString();
    expect(result).toBe("(fluffy ~canine ~feline) rating:q");
  });

  it("handles nested groups without corrupting them", () => {
    const q = new SearchQuery("top ( tag_outer ( tag_inner ) ) rating:s");
    const result = q.withRatings(["e"]).toString();
    expect(result).toBe("top ( tag_outer ( tag_inner ) ) rating:e");
  });

  it("does not treat content inside quotes as group boundaries", () => {
    const q = new SearchQuery("\"a (fake group\" rating:s");
    const result = q.withRatings(["e"]).toString();
    expect(result).toBe("\"a (fake group\" rating:e");
  });
});

describe("SearchQuery - media type canonical table", () => {
  it("all four selected produces no media token", () => {
    expect(new SearchQuery("solo").withMediaTypes(["i", "a", "v", "f"]).toString()).toBe("solo");
  });

  it("zero selected normalizes to unrestricted (same as all four)", () => {
    expect(new SearchQuery("solo").withMediaTypes([]).toString()).toBe("solo");
  });

  it("round-trips every MEDIA_TOKEN entry back to its own key with mediaCustom false", () => {
    for (const [key, token] of Object.entries(MEDIA_TOKEN)) {
      const q = new SearchQuery(token);
      expect(q.media).toBe(key === "iavf" ? MEDIA_ALL : key);
      expect(q.mediaCustom).toBe(false);
    }
  });

  it("matches the exact documented strings for every combination", () => {
    const empty = new SearchQuery("");
    expect(empty.withMediaTypes(["i", "a", "v"]).toString()).toBe("-flash");
    expect(empty.withMediaTypes(["i", "a", "f"]).toString()).toBe("-video");
    expect(empty.withMediaTypes(["i", "v", "f"]).toString()).toBe("-animated_gif -animated_png -animated_webp");
    expect(empty.withMediaTypes(["a", "v", "f"]).toString())
      .toBe("( ~animated_gif ~animated_png ~animated_webp ~video ~flash )");
    expect(empty.withMediaTypes(["i", "a"]).toString()).toBe("-video -flash");
    expect(empty.withMediaTypes(["i", "v"]).toString()).toBe("-animated_gif -animated_png -animated_webp -flash");
    expect(empty.withMediaTypes(["i", "f"]).toString()).toBe("-animated_gif -animated_png -animated_webp -video");
    expect(empty.withMediaTypes(["a", "v"]).toString()).toBe("( ~animated_gif ~animated_png ~animated_webp ~video )");
    expect(empty.withMediaTypes(["a", "f"]).toString()).toBe("( ~animated_gif ~animated_png ~animated_webp ~flash )");
    expect(empty.withMediaTypes(["v", "f"]).toString()).toBe("( ~video ~flash )");
    expect(empty.withMediaTypes(["i"]).toString()).toBe("-animated_gif -animated_png -animated_webp -video -flash");
    expect(empty.withMediaTypes(["a"]).toString()).toBe("( ~animated_gif ~animated_png ~animated_webp )");
    expect(empty.withMediaTypes(["v"]).toString()).toBe("video");
    expect(empty.withMediaTypes(["f"]).toString()).toBe("flash");
  });

  it("never emits positive or negative generic animated in any generated form", () => {
    for (const token of Object.values(MEDIA_TOKEN)) {
      expect(token).not.toMatch(/(^|\s)-?animated(\s|$)/);
    }
  });

  it("repeated toggling cleanly replaces the previous canonical expression", () => {
    let q = new SearchQuery("solo");
    q = q.withMediaTypes(["v"]);
    expect(q.toString()).toBe("solo video");
    q = q.withMediaTypes(["f"]);
    expect(q.toString()).toBe("solo flash");
    q = q.withMediaTypes(["a", "v"]);
    expect(q.toString()).toBe("solo ( ~animated_gif ~animated_png ~animated_webp ~video )");
    q = q.withMediaTypes(["i"]);
    expect(q.toString()).toBe("solo -animated_gif -animated_png -animated_webp -video -flash");
    q = q.withMediaTypes(["i", "a", "v", "f"]);
    expect(q.toString()).toBe("solo");
  });
});

describe("SearchQuery - media type manual forms (authoritative)", () => {
  it("recognizes bare video/flash and their negations as authoritative", () => {
    expect(media("video").media).toBe("v");
    expect(media("video").mediaCustom).toBe(false);
    expect(media("flash").media).toBe("f");
    expect(media("-video").media).toBe("iaf");
    expect(media("-flash").media).toBe("iav");
    for (const q of ["video", "flash", "-video", "-flash"]) expect(media(q).mediaCustom).toBe(false);
  });

  it("recognizes the three-subtype exclusion as ivf, authoritatively", () => {
    const state = media("-animated_gif -animated_png -animated_webp");
    expect(state.media).toBe("ivf");
    expect(state.mediaCustom).toBe(false);
  });

  it("generating if/i from checkboxes never uses -animated", () => {
    expect(new SearchQuery("").withMediaTypes(["i", "f"]).toString()).not.toMatch(/-animated(\s|$)/);
    expect(new SearchQuery("").withMediaTypes(["i"]).toString()).not.toMatch(/-animated(\s|$)/);
  });
});

describe("SearchQuery - media type legacy animated aliases (non-authoritative)", () => {
  it("bare animated resolves to av but is marked custom", () => {
    const state = media("animated");
    expect(state.media).toBe("av");
    expect(state.mediaCustom).toBe(true);
  });

  it("animated -video resolves to a but is marked custom", () => {
    const state = media("animated -video");
    expect(state.media).toBe("a");
    expect(state.mediaCustom).toBe(true);
  });

  it("-animated alone resolves to if but is marked custom", () => {
    const state = media("-animated");
    expect(state.media).toBe("if");
    expect(state.mediaCustom).toBe(true);
  });

  it("-animated -video -flash resolves to i but is marked custom", () => {
    const state = media("-animated -video -flash");
    expect(state.media).toBe("i");
    expect(state.mediaCustom).toBe(true);
  });

  it("( ~animated ~flash ) resolves to avf but is marked custom", () => {
    const state = media("( ~animated ~flash )");
    expect(state.media).toBe("avf");
    expect(state.mediaCustom).toBe(true);
  });

  it("interacting with the controls replaces a legacy alias with the authoritative form", () => {
    for (const [legacy, key] of [
      ["animated", "av"],
      ["animated -video", "a"],
      ["-animated", "if"],
      ["-animated -video -flash", "i"],
      ["( ~animated ~flash )", "avf"],
    ] as const) {
      const rewritten = new SearchQuery(legacy).withMediaTypes(key.split(""));
      expect(rewritten.toString()).toBe(MEDIA_TOKEN[key]);
      expect(rewritten.mediaCustom).toBe(false);
      expect(rewritten.media).toBe(key);
    }
  });
});

describe("SearchQuery - media type ambiguity (no ownership, no rewrite)", () => {
  it("two competing canonical groups resolve to unrestricted + custom, owning nothing", () => {
    const q = new SearchQuery("( ~video ~flash ) ( ~animated_gif ~animated_png ~animated_webp )");
    expect(q.media).toBe(MEDIA_ALL);
    expect(q.mediaCustom).toBe(true);
    expect(q.withMediaTypes(["v"]).toString()).toBe(
      "( ~video ~flash ) ( ~animated_gif ~animated_png ~animated_webp ) video",
    );
  });

  it("a canonical group mixed with a stray simple token is ambiguous, owning nothing", () => {
    const q = new SearchQuery("video ( ~animated_gif ~animated_png ~animated_webp ~flash )");
    expect(q.media).toBe(MEDIA_ALL);
    expect(q.mediaCustom).toBe(true);
  });
});

describe("SearchQuery - grouped OR syntax must use a required outer group with optional members", () => {
  it("~( video flash ) is NOT the OR-group shape: it is custom/unowned", () => {
    // ~(...) means the whole group is optional while its unprefixed members are each
    // individually required within it — i.e. "optionally, video AND flash," not
    // "video OR flash." It must never be treated as an alias for `vf`.
    const state = media("~( video flash )");
    expect(state.media).toBe(MEDIA_ALL);
    expect(state.mediaCustom).toBe(true);

    const q = new SearchQuery("~( video flash )");
    expect(q.withMediaTypes(["i"]).toString()).toBe(
      "~( video flash ) -animated_gif -animated_png -animated_webp -video -flash",
    );
  });

  it("( ~video ~flash ) is the correct OR-group shape: it resolves cleanly to vf", () => {
    const state = media("( ~video ~flash )");
    expect(state.media).toBe("vf");
    expect(state.mediaCustom).toBe(false);

    const q = new SearchQuery("( ~video ~flash )");
    expect(q.withMediaTypes(["i", "a", "v", "f"]).toString()).toBe("");
  });
});

describe("SearchQuery - standalone animated-image subtype tags force custom", () => {
  it("animated_gif alone is custom with nothing owned", () => {
    const state = media("animated_gif");
    expect(state.media).toBe(MEDIA_ALL);
    expect(state.mediaCustom).toBe(true);
  });

  it("animated_png and animated_webp alone behave the same way", () => {
    expect(media("animated_png").mediaCustom).toBe(true);
    expect(media("animated_png").media).toBe(MEDIA_ALL);
    expect(media("animated_webp").mediaCustom).toBe(true);
    expect(media("animated_webp").media).toBe(MEDIA_ALL);
  });

  it("animated_gif video stays owned as Video-only, but is still marked custom", () => {
    const state = media("animated_gif video");
    expect(state.media).toBe("v");
    expect(state.mediaCustom).toBe(true);
  });

  it("animated_gif -flash stays owned as iav, but is still marked custom", () => {
    const state = media("animated_gif -flash");
    expect(state.media).toBe("iav");
    expect(state.mediaCustom).toBe(true);
  });
});

describe("SearchQuery - custom groups do not poison a separately owned expression", () => {
  it("an unrecognized all-vocabulary group alone is custom, owning nothing", () => {
    const state = media("~( animated_gif video )");
    expect(state.media).toBe(MEDIA_ALL);
    expect(state.mediaCustom).toBe(true);
  });

  it("a custom group plus a bare flash keeps flash owned", () => {
    const state = media("~( animated_gif video ) flash");
    expect(state.media).toBe("f");
    expect(state.mediaCustom).toBe(true);
  });

  it("changing selection replaces only the owned token, preserving the custom group", () => {
    const q = new SearchQuery("~( animated_gif video ) flash");
    expect(q.withMediaTypes(["v"]).toString()).toBe("~( animated_gif video ) video");
  });

  it("a custom group plus a canonical group keeps the canonical group owned", () => {
    const q = new SearchQuery("~( animated_gif video ) ( ~video ~flash )");
    expect(q.media).toBe("vf");
    expect(q.mediaCustom).toBe(true);
    expect(q.withMediaTypes(["i"]).toString()).toBe(
      "~( animated_gif video ) -animated_gif -animated_png -animated_webp -video -flash",
    );
  });
});

describe("SearchQuery - owned sub-expressions do not accumulate across repeated interaction", () => {
  it("full lifecycle: animated_gif -> video -> flash -> image only", () => {
    let q = new SearchQuery("animated_gif");
    expect(q.mediaCustom).toBe(true);

    q = q.withMediaTypes(["v"]);
    expect(q.toString()).toBe("animated_gif video");

    q = q.withMediaTypes(["f"]);
    expect(q.toString()).toBe("animated_gif flash");

    q = q.withMediaTypes(["i"]);
    expect(q.toString()).toBe("animated_gif -animated_gif -animated_png -animated_webp -video -flash");
  });
});

describe("SearchQuery - write-side conservatism", () => {
  it("a lone positive animated_gif tag survives a media-control update untouched", () => {
    const q = new SearchQuery("animated_gif");
    expect(q.withMediaTypes(["v"]).toString()).toBe("animated_gif video");
  });

  it("an unrecognized media-only OR group survives, new selection appended alongside it", () => {
    const q = new SearchQuery("~( animated_gif video )");
    expect(q.withMediaTypes(["f"]).toString()).toBe("~( animated_gif video ) flash");
  });

  it("each canonical OR group this feature generates is fully removed and replaced", () => {
    for (const key of ["a", "av", "avf", "af", "vf"]) {
      const q = new SearchQuery(MEDIA_TOKEN[key]);
      const next = q.withMediaTypes(["i", "a", "v", "f"]);
      expect(next.toString()).toBe("");
    }
  });

  it("each canonical multi-token negative form is removed completely with no leftovers", () => {
    const q = new SearchQuery("-animated_gif -animated_png -animated_webp -video -flash");
    expect(q.withMediaTypes(["i", "a", "v", "f"]).toString()).toBe("");
  });
});

describe("SearchQuery - media coexists with unrelated content and other controls", () => {
  it("unrelated tags, quoted values, and unrelated groups survive a media round trip", () => {
    const q = new SearchQuery("solo \"quoted value\" (fluffy ~canine ~feline)");
    const result = q.withMediaTypes(["v"]).toString();
    expect(result).toBe("solo \"quoted value\" (fluffy ~canine ~feline) video");
  });

  it("case and whitespace variation in a manually-typed group is still recognized", () => {
    expect(media("(~VIDEO   ~flash)").media).toBe("vf");
    expect(media("(~VIDEO   ~flash)").mediaCustom).toBe(false);
  });

  it("coexists with rating, order, inpool, ischild, and isparent", () => {
    const q = new SearchQuery("rating:s order:score inpool:true ischild:true isparent:false");
    const withMedia = q.withMediaTypes(["v"]);
    expect(withMedia.toString()).toBe("rating:s order:score inpool:true ischild:true isparent:false video");
    expect(withMedia.ratings).toBe("s");
    expect(withMedia.order).toBe("score");
    expect(withMedia.inpool).toBe("true");
    expect(withMedia.ischild).toBe("true");
    expect(withMedia.isparent).toBe("false");
  });

  it("a ~(...) group not composed entirely of media vocabulary is left untouched", () => {
    const q = new SearchQuery("~( video solo )");
    expect(q.media).toBe(MEDIA_ALL);
    expect(q.mediaCustom).toBe(false);
    expect(q.withMediaTypes(["f"]).toString()).toBe("~( video solo ) flash");
  });
});

describe("SearchQuery - sound canonical states", () => {
  it("unrestricted has no sound-related term", () => {
    expect(sound("solo").sound).toBe(SOUND_NONE);
    expect(new SearchQuery("solo").withSound(false, false, false).toString()).toBe("solo");
  });

  it("No sound -> no_sound", () => {
    expect(sound("no_sound").sound).toBe(SOUND_NO_SOUND);
    expect(sound("no_sound").soundCustom).toBe(false);
    expect(new SearchQuery("solo").withSound(true, false, false).toString()).toBe("solo no_sound");
  });

  it("Sound + Sound warning -> sound", () => {
    expect(sound("sound").sound).toBe(SOUND_BOTH);
    expect(sound("sound").soundCustom).toBe(false);
    expect(new SearchQuery("solo").withSound(false, true, true).toString()).toBe("solo sound");
  });

  it("Sound only -> sound -sound_warning", () => {
    expect(sound("sound -sound_warning").sound).toBe(SOUND_ONLY);
    expect(sound("sound -sound_warning").soundCustom).toBe(false);
    expect(new SearchQuery("solo").withSound(false, true, false).toString()).toBe("solo sound -sound_warning");
  });

  it("Sound warning only -> sound_warning (no redundant `sound sound_warning`)", () => {
    expect(sound("sound_warning").sound).toBe(SOUND_WARNING_ONLY);
    expect(sound("sound_warning").soundCustom).toBe(false);
    const result = new SearchQuery("solo").withSound(false, false, true).toString();
    expect(result).toBe("solo sound_warning");
    expect(result).not.toMatch(/\bsound\s+sound_warning\b/);
  });

  it("repeated transitions cleanly replace the previous owned sound expression", () => {
    let q = new SearchQuery("solo");
    q = q.withSound(false, true, true);
    expect(q.toString()).toBe("solo sound");
    q = q.withSound(false, true, false);
    expect(q.toString()).toBe("solo sound -sound_warning");
    q = q.withSound(false, false, true);
    expect(q.toString()).toBe("solo sound_warning");
    q = q.withSound(true, false, false);
    expect(q.toString()).toBe("solo no_sound");
    q = q.withSound(false, false, false);
    expect(q.toString()).toBe("solo");
  });

  it("no_sound is never generated alongside sound or sound_warning", () => {
    // Even starting from a state that already has sound-bearing content, selecting
    // No sound must fully replace it, never coexist with it.
    const q = new SearchQuery("sound").withSound(true, false, false);
    expect(q.toString()).toBe("no_sound");
    expect(q.toString()).not.toMatch(/\bsound\b/);
  });

  it("unrelated tags and other controls survive sound changes", () => {
    const q = new SearchQuery("solo rating:s order:score (fluffy ~canine ~feline)").withSound(false, true, true);
    expect(q.toString()).toBe("solo rating:s order:score (fluffy ~canine ~feline) sound");
    expect(q.ratings).toBe("s");
    expect(q.order).toBe("score");
  });

  it("sound changes survive alongside media type selections and vice versa", () => {
    const q = new SearchQuery("solo").withMediaTypes(["v"]).withSound(false, true, true);
    expect(q.toString()).toBe("solo video sound");
    expect(q.media).toBe("v");
    expect(q.sound).toBe(SOUND_BOTH);
  });

  it("ambiguous/unowned sound expressions survive untouched", () => {
    for (const raw of ["-sound", "-no_sound", "no_sound sound", "sound sound_warning"]) {
      const q = new SearchQuery(raw);
      expect(q.sound).toBe(SOUND_NONE);
      expect(q.soundCustom).toBe(true);
      // Selecting a new state must append, never delete, the unrecognized content.
      const written = q.withSound(true, false, false).toString();
      expect(written.startsWith(raw)).toBe(true);
      expect(written).toBe(`${raw} no_sound`);
    }
  });

  it("a sound-vocabulary word inside an arbitrary group is not equated with any state, and is preserved", () => {
    // Sound has no OR-group semantics at all, so a group is never inspected for sound
    // words — it's simply unrelated content as far as the Sound control is concerned.
    const q = new SearchQuery("~( sound solo )");
    expect(q.sound).toBe(SOUND_NONE);
    expect(q.soundCustom).toBe(false);
    expect(q.withSound(true, false, false).toString()).toBe("~( sound solo ) no_sound");
  });
});
