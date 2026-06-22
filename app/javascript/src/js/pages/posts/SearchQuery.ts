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

interface Token {
  text: string;
  start: number;
  end: number;
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
    };

    for (const token of SearchQuery.scanTopLevelTokens(raw)) {
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
    return state;
  }

  /**
   * Splits `query` into whitespace-delimited tokens, skipping anything inside
   * parentheses or double-quoted strings. Only top-level tokens (depth 0) are returned,
   * so grouped sub-expressions like `(order:score ~order:id)` are treated as one opaque token.
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

      if (whitespace && start !== null && (atEnd || !quoted)) {
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
