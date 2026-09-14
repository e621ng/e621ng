export const ORDER_DESC = "desc";
export const ORDER_ASC = "asc";

/**
 * Sentinel returned by parse methods when the order metatag is present but unrecognised.
 * Signals that the raw query should not be modified on write.
 */
export const ORDER_CUSTOM = "__custom";

export const ORDER_VALUES: Record<string, { label: string; icon: string; flat?: boolean }> = {
  id: { label: "ID", icon: "hash" },
  score: { label: "Score", icon: "trending_up" },
  hot: { label: "Hot", icon: "flame", flat: true },
  favcount: { label: "Favorites", icon: "star" },

  created: { label: "Date", icon: "clock_fading" },
  updated: { label: "Updated", icon: "clock_fading" },
  change: { label: "Change", icon: "reset" },
  comment: { label: "Comment", icon: "message_square" },
  comment_count: { label: "Comment", icon: "message_square" },
  comment_bumped: { label: "Comment", icon: "message_square" },
  mpixels: { label: "Resolution", icon: "fullscreen" },
  filesize: { label: "Filesize", icon: "file" },
  duration: { label: "Duration", icon: "clock_fading" },
  tagcount: { label: "Tags", icon: "tags" },
  general_tags: { label: "Tags", icon: "tags" },
  artist_tags: { label: "Tags", icon: "tags" },
  contributor_tags: { label: "Tags", icon: "tags" },
  copyright_tags: { label: "Tags", icon: "tags" },
  character_tags: { label: "Tags", icon: "tags" },
  species_tags: { label: "Tags", icon: "tags" },
  invalid_tags: { label: "Tags", icon: "tags" },
  meta_tags: { label: "Tags", icon: "tags" },
  lore_tags: { label: "Tags", icon: "tags" },
  md5: { label: "MD5", icon: "hash" },
  note: { label: "Notes", icon: "notepad" },
  random: { label: "Random", icon: "shuffle", flat: true },
  landscape: { label: "Landscape", icon: "images", flat: true },
  portrait: { label: "Portrait", icon: "images", flat: true },
};

const SUPPORTED_ORDER_VALUES: string[] = Object.entries(ORDER_VALUES)
  .flatMap(([key, val]) => (val.flat ? [key] : [key, key + "_asc"]));

export const RATINGS = ["s", "q", "e"];
const RATING_ALL = RATINGS.join("");

/**
 * Maps a sorted concatenation of active rating letters to the corresponding query metatag.
 * An empty string means all ratings are active (no metatag needed).
 * e.g. active ratings ["s", "q"] → key "sq" → "-rating:e"
 */
export const RATING_TOKEN: Record<string, string> = {
  sqe: "",
  sq: "-rating:e",
  qe: "-rating:s",
  se: "-rating:q",
  s: "rating:s",
  q: "rating:q",
  e: "rating:e",
};

export const MEDIA_LETTERS = ["i", "a", "v", "f"];
export const MEDIA_ALL = MEDIA_LETTERS.join("");

/**
 * Maps a sorted concatenation of active media-type letters to the corresponding query
 * expression. Every entry is built exclusively from tags that are force-recomputed on
 * every post save (`video`, `flash`, `animated_gif`, `animated_png`, `animated_webp`),
 * never the generic `animated` tag — which is only ever set once at upload time and can
 * go stale in either direction. An empty string means all four categories are active
 * (no expression needed).
 */
export const MEDIA_TOKEN: Record<string, string> = {
  iavf: "",
  iav: "-flash",
  iaf: "-video",
  ivf: "-animated_gif -animated_png -animated_webp",
  avf: "( ~animated_gif ~animated_png ~animated_webp ~video ~flash )",
  ia: "-video -flash",
  iv: "-animated_gif -animated_png -animated_webp -flash",
  if: "-animated_gif -animated_png -animated_webp -video",
  av: "( ~animated_gif ~animated_png ~animated_webp ~video )",
  af: "( ~animated_gif ~animated_png ~animated_webp ~flash )",
  vf: "( ~video ~flash )",
  i: "-animated_gif -animated_png -animated_webp -video -flash",
  a: "( ~animated_gif ~animated_png ~animated_webp )",
  v: "video",
  f: "flash",
};

const MEDIA_VOCABULARY = ["animated", "animated_gif", "animated_png", "animated_webp", "video", "flash"];

/**
 * Recognized OR-group word-sets, in the `( ~a ~b ~c )` shape: an unprefixed (`must`)
 * outer group whose every member carries its own `~` (`should`) prefix — this is what
 * actually means "at least one of a/b/c" to the backend (`app/logical/tag_query.rb`).
 * An *outer*-prefixed group like `~( a b )` means something different (the whole group
 * is optional, but its unprefixed members are individually required within it), so it
 * is never treated as one of these shapes — see `classifyMediaToken`.
 * `authoritative: false` marks the one legacy shape built on the generic `animated`
 * tag — still recognized/ownable for reading and replacing a hand-typed query, but
 * never emitted by `MEDIA_TOKEN`.
 */
const MEDIA_GROUP_SHAPES: { key: string; authoritative: boolean; words: string[] }[] = [
  { key: "a", authoritative: true, words: ["animated_gif", "animated_png", "animated_webp"] },
  { key: "av", authoritative: true, words: ["animated_gif", "animated_png", "animated_webp", "video"] },
  { key: "avf", authoritative: true, words: ["animated_gif", "animated_png", "animated_webp", "video", "flash"] },
  { key: "af", authoritative: true, words: ["animated_gif", "animated_png", "animated_webp", "flash"] },
  { key: "vf", authoritative: true, words: ["video", "flash"] },
  { key: "avf", authoritative: false, words: ["animated", "flash"] },
];

/**
 * Recognized simple positive/negative token sets. `authoritative: false` marks the
 * legacy shapes built on the generic `animated` tag (see `MEDIA_GROUP_SHAPES`).
 */
const MEDIA_SIMPLE_SHAPES: { key: string; authoritative: boolean; pos: string[]; neg: string[] }[] = [
  { key: "ivf", authoritative: true, pos: [], neg: ["animated_gif", "animated_png", "animated_webp"] },
  { key: "iv", authoritative: true, pos: [], neg: ["animated_gif", "animated_png", "animated_webp", "flash"] },
  { key: "ia", authoritative: true, pos: [], neg: ["video", "flash"] },
  { key: "iav", authoritative: true, pos: [], neg: ["flash"] },
  { key: "iaf", authoritative: true, pos: [], neg: ["video"] },
  { key: "if", authoritative: true, pos: [], neg: ["animated_gif", "animated_png", "animated_webp", "video"] },
  { key: "i", authoritative: true, pos: [], neg: ["animated_gif", "animated_png", "animated_webp", "video", "flash"] },
  { key: "v", authoritative: true, pos: ["video"], neg: [] },
  { key: "f", authoritative: true, pos: ["flash"], neg: [] },
  { key: "if", authoritative: false, pos: [], neg: ["animated"] },
  { key: "i", authoritative: false, pos: [], neg: ["animated", "video", "flash"] },
  { key: "av", authoritative: false, pos: ["animated"], neg: [] },
  { key: "a", authoritative: false, pos: ["animated"], neg: ["video"] },
];

export const SOUND_NONE = "none";
export const SOUND_NO_SOUND = "no_sound";
export const SOUND_BOTH = "both";
export const SOUND_ONLY = "sound_only";
export const SOUND_WARNING_ONLY = "warning_only";

/**
 * Maps each of the five canonical Sound states to its query expression. Unlike Media
 * type, Sound has no OR-group needs — every state is either no token, a single bare
 * tag, or a bare tag plus one negation — so it deliberately uses a much smaller
 * exact-match parser below instead of reusing the Media type group machinery.
 * `sound` intentionally already covers both ordinary sound and `sound_warning`
 * posts (a real e621 tag relationship), so "Sound only" must explicitly exclude
 * `sound_warning` rather than the control ever emitting some other "sound-only" tag.
 */
const SOUND_TOKEN: Record<string, string> = {
  [SOUND_NONE]: "",
  [SOUND_NO_SOUND]: "no_sound",
  [SOUND_BOTH]: "sound",
  [SOUND_ONLY]: "sound -sound_warning",
  [SOUND_WARNING_ONLY]: "sound_warning",
};

/** Recognized exact positive/negative word-sets for the five Sound states. */
const SOUND_SHAPES: { key: string; pos: string[]; neg: string[] }[] = [
  { key: SOUND_NO_SOUND, pos: ["no_sound"], neg: [] },
  { key: SOUND_BOTH, pos: ["sound"], neg: [] },
  { key: SOUND_ONLY, pos: ["sound"], neg: ["sound_warning"] },
  { key: SOUND_WARNING_ONLY, pos: ["sound_warning"], neg: [] },
];

interface Token {
  text: string;
  start: number;
  end: number;
}

interface SoundSignals {
  pos: { word: string; token: Token }[];
  neg: { word: string; token: Token }[];
}

interface SoundState {
  sound: string;
  soundCustom: boolean;
  ownedTokens: Token[];
}

type MediaSignal
  = | { kind: "pos"; word: string; token: Token }
  | { kind: "neg"; word: string; token: Token }
  | { kind: "customPos"; token: Token }
  | { kind: "canonicalGroup"; key: string; authoritative: boolean; token: Token }
  | { kind: "customGroup"; token: Token };

interface MediaSignals {
  pos: { word: string; token: Token }[];
  neg: { word: string; token: Token }[];
  canonicalGroups: { key: string; authoritative: boolean; token: Token }[];
  customGroups: Token[];
  customPos: Token[];
}

interface OwnableMediaCombo {
  key: string | null;
  tokens: Token[];
  authoritative: boolean;
}

interface MediaState {
  media: string;
  mediaCustom: boolean;
  ownedTokens: Token[];
}

interface OrderState {
  value: string;
  direction: string;
}

interface RatingToken {
  value: string;
  negated: boolean;
}

interface ParsedState {
  order: string;
  direction: string;
  inpool: string;
  ischild: string;
  isparent: string;
  ratings: string;
  media: string;
  mediaCustom: boolean;
  sound: string;
  soundCustom: boolean;
}

/**
 * Immutable value object representing a post search query string.
 * Parses metatags relevant to the advanced search UI (order, inpool, rating) on demand.
 * Mutation methods (`withOrder`, `withInpool`, `withRatings`) return a new instance
 * with the corresponding metatag replaced in the raw string.
 */
export default class SearchQuery {
  private readonly _raw: string;
  private readonly _state: ParsedState;

  constructor (raw: string) {
    this._raw = raw;
    this._state = SearchQuery.parse(raw);
  }

  get order (): string { return this._state.order; }
  get direction (): string { return this._state.direction; }
  get inpool (): string { return this._state.inpool; }
  get ischild (): string { return this._state.ischild; }
  get isparent (): string { return this._state.isparent; }
  get ratings (): string { return this._state.ratings; }
  get media (): string { return this._state.media; }
  get mediaCustom (): boolean { return this._state.mediaCustom; }
  get sound (): string { return this._state.sound; }
  get soundCustom (): boolean { return this._state.soundCustom; }

  withOrder (value: string, direction: string): SearchQuery {
    return new SearchQuery(SearchQuery.replaceOrderMetatags(this._raw, value, direction));
  }

  withInpool (value: string): SearchQuery {
    return new SearchQuery(SearchQuery.replaceInpoolMetatags(this._raw, value));
  }

  withIschild (value: string): SearchQuery {
    return new SearchQuery(SearchQuery.replaceIschildMetatags(this._raw, value));
  }

  withIsparent (value: string): SearchQuery {
    return new SearchQuery(SearchQuery.replaceIsparentMetatags(this._raw, value));
  }

  withRatings (ratings: string[]): SearchQuery {
    return new SearchQuery(SearchQuery.replaceRatingMetatags(this._raw, ratings));
  }

  withMediaTypes (selected: string[]): SearchQuery {
    return new SearchQuery(SearchQuery.replaceMediaMetatags(this._raw, selected));
  }

  withSound (noSound: boolean, hasSound: boolean, hasWarning: boolean): SearchQuery {
    return new SearchQuery(SearchQuery.replaceSoundMetatags(this._raw, noSound, hasSound, hasWarning));
  }

  toString (): string {
    return this._raw;
  }

  private static parse (raw: string): ParsedState {
    const state: ParsedState = {
      order: "",
      direction: ORDER_DESC,
      inpool: "",
      ischild: "",
      isparent: "",
      ratings: RATING_ALL,
      media: MEDIA_ALL,
      mediaCustom: false,
      sound: SOUND_NONE,
      soundCustom: false,
    };

    const tokens = SearchQuery.scanTopLevelTokens(raw);

    for (const token of tokens) {
      const order = SearchQuery.parseOrderToken(token.text);
      if (order) {
        state.order = order.value;
        state.direction = order.direction;
      }

      const inpool = SearchQuery.parseInpoolToken(token.text);
      if (inpool !== null) state.inpool = inpool;

      const ischild = SearchQuery.parseIschildToken(token.text);
      if (ischild !== null) state.ischild = ischild;

      const isparent = SearchQuery.parseIsparentToken(token.text);
      if (isparent !== null) state.isparent = isparent;

      const rating = SearchQuery.parseRatingToken(token.text);
      if (rating) state.ratings = SearchQuery.applyRatingToken(state.ratings, rating);
    }

    if (!state.ratings) state.ratings = RATING_ALL;

    const media = SearchQuery.resolveMediaState(SearchQuery.collectMediaSignals(tokens));
    state.media = media.media;
    state.mediaCustom = media.mediaCustom;

    const sound = SearchQuery.resolveSoundState(SearchQuery.collectSoundSignals(tokens));
    state.sound = sound.sound;
    state.soundCustom = sound.soundCustom;

    return state;
  }

  /**
   * Splits `query` into whitespace-delimited tokens, skipping anything inside
   * parentheses or double-quoted strings. Only top-level tokens (depth 0) are returned,
   * so a grouped sub-expression like `(order:score ~order:id)` is treated as one opaque
   * token even though it contains internal whitespace — a token only ends at whitespace
   * encountered while `depth === 0`, so an unclosed group's internal spaces don't split it.
   */
  private static scanTopLevelTokens (query: string): Token[] {
    const tokens: Token[] = [];
    let depth = 0;
    let quoted = false;
    let start: number | null = null;
    let startDepth = 0;

    for (let i = 0; i <= query.length; i++) {
      const char = query[i] || "";
      const atEnd = i === query.length;
      const whitespace = atEnd || /\s/.test(char);

      if (start === null && !atEnd && !whitespace) {
        start = i;
        startDepth = depth;
      }

      if (whitespace && start !== null && depth === 0 && (atEnd || !quoted)) {
        const text = query.slice(start, i);
        if (startDepth === 0) tokens.push({ text, start, end: i });
        start = null;
      }

      if (atEnd) continue;
      if (char === "\"") quoted = !quoted;
      if (quoted) continue;

      if (char === "(") depth += 1;
      if (char === ")" && depth > 0) depth -= 1;
    }

    return tokens;
  }

  /**
   * Parses an `order:` metatag token into a value/direction pair.
   * A leading `-` negates the direction rather than excluding results:
   * `-order:id_asc` is treated as `order:id` (descending).
   * Unrecognised values return `{ value: ORDER_CUSTOM }` to signal no-op on write.
   */
  private static parseOrderToken (text: string): OrderState | null {
    const match = text.match(/^(-?)order:(.+)$/i);
    if (!match) return null;

    let value = SearchQuery.unquoteMetatagValue(match[2]).toLowerCase();
    const negated = match[1] === "-";

    if (ORDER_VALUES[value]?.flat) {
      return { value: negated ? ORDER_CUSTOM : value, direction: ORDER_DESC };
    }

    if (value.endsWith("_desc")) value = value.slice(0, -5);

    const root = value.replace(/_asc$/, "");
    if (!ORDER_VALUES[root] || ORDER_VALUES[root].flat) {
      return { value: ORDER_CUSTOM, direction: ORDER_DESC };
    }

    let direction = value.endsWith("_asc") ? ORDER_ASC : ORDER_DESC;
    if (negated) direction = direction === ORDER_ASC ? ORDER_DESC : ORDER_ASC;

    return { value: root, direction };
  }

  private static parseInpoolToken (text: string): string | null {
    const match = text.match(/^inpool:(true|false)$/i);
    if (!match) return null;
    return match[1].toLowerCase();
  }

  private static parseRatingToken (text: string): RatingToken | null {
    const match = text.match(/^(-?)rating:(.+)$/i);
    if (!match) return null;

    const value = SearchQuery.unquoteMetatagValue(match[2]).toLowerCase()[0];
    if (!RATINGS.includes(value)) return null;

    return { value, negated: match[1] === "-" };
  }

  private static parseIschildToken (text: string): string | null {
    const match = text.match(/^(?:ischild|hasparent):(true|false)$/i);
    if (!match) return null;
    return match[1].toLowerCase();
  }

  private static parseIsparentToken (text: string): string | null {
    const match = text.match(/^(?:isparent|haschild|haschildren):(true|false)$/i);
    if (!match) return null;
    return match[1].toLowerCase();
  }

  /**
   * Updates the active rating set encoded as a sorted string of letters ("sqe", "sq", …).
   * A negated token removes one letter from the set; a positive token sets the entire set
   * to just that letter (not an additive include).
   */
  private static applyRatingToken (ratings: string, rating: RatingToken): string {
    if (rating.negated) return ratings.replace(rating.value, "");
    return rating.value;
  }

  private static replaceOrderMetatags (query: string, value: string, direction: string): string {
    const orderValue = SearchQuery.orderMetatagValue(value, direction);
    if (orderValue === ORDER_CUSTOM) return query;

    const newToken = orderValue && SUPPORTED_ORDER_VALUES.includes(orderValue)
      ? "order:" + orderValue
      : "";

    return SearchQuery.replaceTopLevelMetatags(
      query,
      (token) => !!SearchQuery.parseOrderToken(token),
      newToken,
    );
  }

  private static replaceInpoolMetatags (query: string, value: string): string {
    const newToken = value ? "inpool:" + value : "";
    return SearchQuery.replaceTopLevelMetatags(
      query,
      (token) => SearchQuery.parseInpoolToken(token) !== null,
      newToken,
    );
  }

  private static replaceIschildMetatags (query: string, value: string): string {
    const newToken = value ? "ischild:" + value : "";
    return SearchQuery.replaceTopLevelMetatags(
      query,
      (token) => SearchQuery.parseIschildToken(token) !== null,
      newToken,
    );
  }

  private static replaceIsparentMetatags (query: string, value: string): string {
    const newToken = value ? "isparent:" + value : "";
    return SearchQuery.replaceTopLevelMetatags(
      query,
      (token) => SearchQuery.parseIsparentToken(token) !== null,
      newToken,
    );
  }

  private static replaceRatingMetatags (query: string, ratings: string[]): string {
    return SearchQuery.replaceTopLevelMetatags(
      query,
      (token) => SearchQuery.parseRatingToken(token) !== null,
      SearchQuery.ratingMetatagToken(ratings),
    );
  }

  /**
   * Classifies a single top-level token into one of the media-type signal kinds, or
   * `null` if it's not media-related at all (e.g. an unrelated tag, or a `(...)` group
   * containing a foreign, non-vocabulary word).
   *
   * Group handling distinguishes the *shape* of a `(...)` expression, not just its
   * word content: only an unprefixed outer group whose every member carries its own
   * `~` prefix (e.g. `( ~video ~flash )`) means "at least one of" to the backend, so
   * only that exact shape is ever treated as a canonical/alias group. Any other
   * prefix arrangement built from the same vocabulary — including the outer-`~`
   * form `~( video flash )`, which means something else entirely (see
   * `MEDIA_GROUP_SHAPES`) — is classified as an unowned custom group instead.
   */
  private static classifyMediaToken (token: Token): MediaSignal | null {
    const pos = token.text.match(/^(video|flash|animated)$/i);
    if (pos) return { kind: "pos", word: pos[1].toLowerCase(), token };

    const customPos = token.text.match(/^(animated_gif|animated_png|animated_webp)$/i);
    if (customPos) return { kind: "customPos", token };

    const neg = token.text.match(/^-(video|flash|animated|animated_gif|animated_png|animated_webp)$/i);
    if (neg) return { kind: "neg", word: neg[1].toLowerCase(), token };

    const group = token.text.match(/^([-~]?)\((.+)\)$/i);
    if (group) {
      const outerPrefix = group[1];
      const innerWords = group[2].trim().split(/\s+/).filter((w) => w.length > 0);
      if (innerWords.length === 0) return null;

      const members = innerWords.map((w) => {
        const memberMatch = w.match(/^([-~]?)(.+)$/i);
        return { prefix: memberMatch ? memberMatch[1] : "", word: (memberMatch ? memberMatch[2] : w).toLowerCase() };
      });
      if (!members.every((m) => MEDIA_VOCABULARY.includes(m.word))) return null;

      const isOrGroupShape = outerPrefix === "" && members.every((m) => m.prefix === "~");
      if (isOrGroupShape) {
        const shape = SearchQuery.matchMediaGroupShape(members.map((m) => m.word));
        if (shape) return { kind: "canonicalGroup", key: shape.key, authoritative: shape.authoritative, token };
      }

      return { kind: "customGroup", token };
    }

    return null;
  }

  private static matchMediaGroupShape (words: string[]): { key: string; authoritative: boolean } | null {
    const shape = MEDIA_GROUP_SHAPES.find((s) => SearchQuery.sameWordSet(s.words, words));
    return shape ? { key: shape.key, authoritative: shape.authoritative } : null;
  }

  private static sameWordSet (a: string[], b: string[]): boolean {
    if (a.length !== b.length) return false;
    const sortedA = [...a].sort();
    const sortedB = [...b].sort();
    return sortedA.every((word, index) => word === sortedB[index]);
  }

  /** Classifies every top-level token into the media-type signal buckets. */
  private static collectMediaSignals (tokens: Token[]): MediaSignals {
    const signals: MediaSignals = { pos: [], neg: [], canonicalGroups: [], customGroups: [], customPos: [] };

    for (const token of tokens) {
      const signal = SearchQuery.classifyMediaToken(token);
      if (!signal) continue;

      switch (signal.kind) {
        case "pos": signals.pos.push({ word: signal.word, token: signal.token }); break;
        case "neg": signals.neg.push({ word: signal.word, token: signal.token }); break;
        case "customPos": signals.customPos.push(signal.token); break;
        case "canonicalGroup":
          signals.canonicalGroups.push({ key: signal.key, authoritative: signal.authoritative, token: signal.token });
          break;
        case "customGroup": signals.customGroups.push(signal.token); break;
      }
    }

    return signals;
  }

  /**
   * Resolves the "ownable" portion of the media signals (ignoring custom/unownable
   * signals entirely) to a checkbox-state key. Returns `key: null` when the ownable
   * portion is itself ambiguous (more than one canonical group, or a canonical group
   * mixed with stray simple tokens, or a simple-token set that doesn't exactly match
   * a recognized combination) — the only case where media-related content is present
   * but nothing is safe to own/replace.
   */
  private static resolveOwnableMediaCombo (
    pos: { word: string; token: Token }[],
    neg: { word: string; token: Token }[],
    canonicalGroups: { key: string; authoritative: boolean; token: Token }[],
  ): OwnableMediaCombo {
    if (canonicalGroups.length === 1 && pos.length === 0 && neg.length === 0) {
      const group = canonicalGroups[0];
      return { key: group.key, tokens: [group.token], authoritative: group.authoritative };
    }

    if (canonicalGroups.length === 0) {
      const posWords = pos.map((p) => p.word);
      const negWords = neg.map((n) => n.word);
      const shape = MEDIA_SIMPLE_SHAPES.find((s) => SearchQuery.sameWordSet(s.pos, posWords) && SearchQuery.sameWordSet(s.neg, negWords));

      if (shape) {
        return {
          key: shape.key,
          tokens: [...pos.map((p) => p.token), ...neg.map((n) => n.token)],
          authoritative: shape.authoritative,
        };
      }
    }

    return { key: null, tokens: [], authoritative: true };
  }

  /**
   * Resolves the full media-type display state from the classified signals: the
   * currently owned/recognized selection (`media`, defaulting to `MEDIA_ALL`), whether
   * additional unrepresentable content coexists (`mediaCustom`), and exactly which
   * tokens are safe to remove on the next write (`ownedTokens`). `media` and
   * `mediaCustom` are independent — a query can have a cleanly owned selection while
   * still being flagged custom, either because of separate unownable content or
   * because the owned match itself depends on the non-authoritative generic
   * `animated` tag.
   */
  private static resolveMediaState (signals: MediaSignals): MediaState {
    const { pos, neg, canonicalGroups, customGroups, customPos } = signals;
    const hasCustomSignal = customPos.length > 0 || customGroups.length > 0;
    const hasAnySignal = hasCustomSignal || pos.length > 0 || neg.length > 0 || canonicalGroups.length > 0;

    if (!hasAnySignal) return { media: MEDIA_ALL, mediaCustom: false, ownedTokens: [] };

    const { key, tokens: ownedTokens, authoritative } = SearchQuery.resolveOwnableMediaCombo(pos, neg, canonicalGroups);
    const ownableAmbiguous = key === null && (pos.length > 0 || neg.length > 0 || canonicalGroups.length > 0);
    const nonAuthoritativeMatch = key !== null && !authoritative;

    return {
      media: key ?? MEDIA_ALL,
      mediaCustom: hasCustomSignal || ownableAmbiguous || nonAuthoritativeMatch,
      ownedTokens,
    };
  }

  private static mediaMetatagToken (key: string): string {
    return MEDIA_TOKEN[key] || "";
  }

  /**
   * Replaces the currently owned media-type expression (if any) with the canonical
   * expression for `selected`. Never deletes media-related content it doesn't own
   * (see `resolveOwnableMediaCombo`) — an unrepresentable custom expression is left
   * untouched and the new selection is simply appended alongside it.
   */
  private static replaceMediaMetatags (query: string, selected: string[]): string {
    const key = selected.length
      ? [...selected].sort((a, b) => MEDIA_LETTERS.indexOf(a) - MEDIA_LETTERS.indexOf(b)).join("")
      : MEDIA_ALL;
    const newToken = SearchQuery.mediaMetatagToken(key);

    const tokens = SearchQuery.scanTopLevelTokens(query);
    const { ownedTokens } = SearchQuery.resolveMediaState(SearchQuery.collectMediaSignals(tokens));

    let result = query;
    for (const token of [...ownedTokens].sort((a, b) => a.start - b.start).reverse()) {
      result = SearchQuery.removeTokenRange(result, token.start, token.end);
    }

    result = result.trim();
    if (newToken) result = [result, newToken].filter((n) => n).join(" ");

    return result;
  }

  private static classifySoundToken (token: Token): { kind: "pos" | "neg"; word: string; token: Token } | null {
    const pos = token.text.match(/^(no_sound|sound|sound_warning)$/i);
    if (pos) return { kind: "pos", word: pos[1].toLowerCase(), token };

    const neg = token.text.match(/^-(no_sound|sound|sound_warning)$/i);
    if (neg) return { kind: "neg", word: neg[1].toLowerCase(), token };

    return null;
  }

  /** Classifies every top-level token into the sound signal buckets. */
  private static collectSoundSignals (tokens: Token[]): SoundSignals {
    const signals: SoundSignals = { pos: [], neg: [] };

    for (const token of tokens) {
      const signal = SearchQuery.classifySoundToken(token);
      if (!signal) continue;
      signals[signal.kind].push({ word: signal.word, token: signal.token });
    }

    return signals;
  }

  /**
   * Resolves the Sound state from exactly the five canonical signal combinations in
   * `SOUND_SHAPES`. Anything else — a lone negation like `-sound`/`-no_sound`, a
   * contradictory `no_sound sound`, a redundant `sound sound_warning`, or any other
   * combination — is left as `SOUND_NONE` with `soundCustom: true` and no owned
   * tokens, so it's recognized as present but never silently equated with one of the
   * five UI states or deleted.
   */
  private static resolveSoundState (signals: SoundSignals): SoundState {
    const { pos, neg } = signals;
    if (pos.length === 0 && neg.length === 0) {
      return { sound: SOUND_NONE, soundCustom: false, ownedTokens: [] };
    }

    const posWords = pos.map((p) => p.word);
    const negWords = neg.map((n) => n.word);
    const shape = SOUND_SHAPES.find((s) => SearchQuery.sameWordSet(s.pos, posWords) && SearchQuery.sameWordSet(s.neg, negWords));

    if (!shape) return { sound: SOUND_NONE, soundCustom: true, ownedTokens: [] };

    return {
      sound: shape.key,
      soundCustom: false,
      ownedTokens: [...pos.map((p) => p.token), ...neg.map((n) => n.token)],
    };
  }

  private static soundMetatagToken (key: string): string {
    return SOUND_TOKEN[key] || "";
  }

  /**
   * Replaces the currently owned sound expression (if any) with the canonical
   * expression for the given checkbox state. Mirrors `replaceMediaMetatags`'s
   * conservatism: an unrecognized/ambiguous existing sound expression is never
   * deleted, only ever added alongside.
   */
  private static replaceSoundMetatags (query: string, noSound: boolean, hasSound: boolean, hasWarning: boolean): string {
    let key = SOUND_NONE;
    if (noSound) key = SOUND_NO_SOUND;
    else if (hasSound && hasWarning) key = SOUND_BOTH;
    else if (hasSound) key = SOUND_ONLY;
    else if (hasWarning) key = SOUND_WARNING_ONLY;

    const newToken = SearchQuery.soundMetatagToken(key);

    const tokens = SearchQuery.scanTopLevelTokens(query);
    const { ownedTokens } = SearchQuery.resolveSoundState(SearchQuery.collectSoundSignals(tokens));

    let result = query;
    for (const token of [...ownedTokens].sort((a, b) => a.start - b.start).reverse()) {
      result = SearchQuery.removeTokenRange(result, token.start, token.end);
    }

    result = result.trim();
    if (newToken) result = [result, newToken].filter((n) => n).join(" ");

    return result;
  }

  /**
   * Removes all top-level tokens matched by `matcher`, then appends `newToken` at the end.
   * Tokens are removed in reverse index order so earlier removals don't shift later positions.
   */
  private static replaceTopLevelMetatags (
    query: string,
    matcher: (token: string) => boolean,
    newToken: string,
  ): string {
    const tokens = SearchQuery.scanTopLevelTokens(query).filter(token => matcher(token.text));
    let result = query;

    for (const token of tokens.reverse()) {
      result = SearchQuery.removeTokenRange(result, token.start, token.end);
    }

    result = result.trim();
    if (newToken) result = [result, newToken].filter(n => n).join(" ");

    return result;
  }

  private static orderMetatagValue (value: string, direction: string): string {
    if (!value) return "";
    if (value === ORDER_CUSTOM) return ORDER_CUSTOM;
    const entry = ORDER_VALUES[value];
    if (!entry) return ORDER_CUSTOM;
    if (entry.flat) return value;
    return direction === ORDER_ASC ? value + "_asc" : value;
  }

  private static ratingMetatagToken (ratings: string[]): string {
    return RATING_TOKEN[ratings.join("")] || "";
  }

  private static unquoteMetatagValue (value: string): string {
    if (value.startsWith("\"") && value.endsWith("\"")) return value.slice(1, -1);
    return value;
  }

  /**
   * Removes the substring `[start, end)` from `query`, along with adjacent whitespace.
   * Trailing whitespace is consumed first; leading whitespace is consumed only when
   * the token is at the end of the string and has no trailing space to absorb.
   */
  private static removeTokenRange (query: string, start: number, end: number): string {
    let removeStart = start;
    let removeEnd = end;

    while (removeEnd < query.length && /\s/.test(query[removeEnd])) removeEnd += 1;
    if (removeEnd === end) {
      while (removeStart > 0 && /\s/.test(query[removeStart - 1])) removeStart -= 1;
    }

    return query.slice(0, removeStart) + query.slice(removeEnd);
  }
}
