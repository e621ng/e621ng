import Blacklist from "../blacklists";
import Storage from "../storage";
import PostCache from "./PostCache";

/**
 * Represents an individual line in the blacklist.  
 * Contains one or more tokens, which are evaluated to
 * determine whether the post should be hidden.
 */
export default class Filter {

  /**
   * Constructor. Should not normally be used – refer to `Filter.create()` instead.  
   * Keep in mind that the input needs to be cleaned up beforehand:
   * - No comments, inline or standalone
   * - No trailing or leading whitespace
   * - No linebreaks
   * - All lowercase
   * @param {string} text Blacklist line
   */
  constructor(text) {
    this.text = text;
    this._enabled = !Storage.Blacklist.FilterState.has(text);
    this.matchIDs = new Set();

    this.tokens = [];
    this.optional = [];

    // Tokenize the filter parts
    for (let word of new Set(this.text.split(" ").filter((e) => e.trim() !== ""))) {
      let token = new FilterToken(word);
      if (token.optional) this.optional.push(token);
      else this.tokens.push(token);
    }
  }

  /**
   * Creates a new Filter based on the provided text.  
   * Normalizes the text before passing it on to the constructor,
   * and discards any lines that are guaranteed to be invalid.
   * @param {string} text Blacklist line
   * @returns Filter, or null if none was created
   */
  static create(text) {
    text = text.trim();
    
    // Get rid of comments
    if (!text || text.startsWith("#")) return null;
    text = text.toLowerCase().replace(/ #.*$/, "");

    return new Filter(text);
  }

  /** @returns {boolean} Filter state */
  get enabled() {
    return this._enabled;
  }
  set enabled(value) {
    this._enabled = value == true;

    if (this._enabled) Storage.Blacklist.FilterState.delete(this.text);
    else Storage.Blacklist.FilterState.add(this.text);

    for (const element of Blacklist.ui) element.rebuildFilters();
    Blacklist.update_visibility();
  }

  /**
   * Checks if the provided post matches the filter
   * @param {JQuery<HTMLElement>} $post Post to check
   * @returns True if the post matches the filter, false otherwise
   */
  update($post) {
    if ($post.length == 0) return false;
    else if (Array.isArray($post))
      $post = $post[0]; // Deferred posts return an array
    else if ($post.length > 1) {
      // Batch update
      for (const $one of $post)
        this.update($($one));
      return;
    }

    const post = PostCache.fromThumbnail($post);

    // Check if the post matches the filter
    let tokensMatch = false;
    for (const token of this.tokens) {
      tokensMatch = token.test(post);
      if (token.inverted) tokensMatch = !tokensMatch;
      if (!tokensMatch) break;
    }

    // No need to check optional tokens if rest of don't match
    if (tokensMatch && this.optional.length) {
      let optionalTokensMatch = false;
      for (const token of this.optional) {
        optionalTokensMatch = token.test(post);
        if (token.inverted) optionalTokensMatch = !optionalTokensMatch;
        if (optionalTokensMatch) break;
      }

      // If none of the optional tokens match, consider overall match a failure
      if (!optionalTokensMatch) tokensMatch = false;
    }

    if (tokensMatch === true) this.matchIDs.add(post.id);
    else if (tokensMatch === false) this.matchIDs.delete(post.id);
  }
}

/**
 * Represents a single word in the filter.
 * Could be a tag, a metatag, a comparison, etc.
 */
class FilterToken {
  /**
   * Constructor.
   * Provided data should not contain spaces.
   * @param {string} raw Single filter word
   */
  constructor(raw) {
    raw = raw.trim().toLowerCase();

    // Optional
    this.optional = raw.startsWith("~");
    if (this.optional) raw = raw.substring(1);

    // Inverted
    // This allows for both ~ and - to be present
    // Not sure if that's something we want to maintain
    this.inverted = raw.startsWith("-");
    if (this.inverted) raw = raw.substring(1);

    // Get filter type: tag, id, score, rating, etc.
    this.type = FilterUtils.getFilterType(raw);
    if (this.type !== "tag") raw = raw.substring(this.type.length + 1);

    // Get comparison methods: equals, smaller then, etc
    this.comparison = FilterUtils.getComparison(raw);
    if (this.comparison !== "=" && this.comparison !== "..")
      raw = raw.substring(this.comparison.length);

    // Convert data if necessary
    switch (this.type) {
      case "rating":
        this.value = FilterUtils.parseRating(raw);
        break;
      case "sound":
        this.value = FilterUtils.parseYesNo(raw);
        break;
      case "filesize":
        this.value = FilterUtils.parseFilesize(raw);
        break;
      default:
        this.value = raw;
    }
  }

  /**
   * Checks if the filter token is applicable to the specified post
   * @param {any} post Post to test
   * @returns true if the filter token matches
   */
  test(post) {
    return FilterUtils.FilterTests[this.type](this, post);
  }
}

/** Various utilities for the blacklist filters */
let FilterUtils = {

  /**
   * Tests for various filter types.
   * Each entry should return a `(token, post) => bool` function.
   */
  FilterTests: {
    tag: (token, post) => FilterUtils.tagsMatchesFilter(post, token.value),
    tagcount: (token, post) => FilterUtils.compare(post.tagcount, token),

    id: (token, post) => FilterUtils.compare(post.id, token),
    status: (token, post) => post.flags.indexOf(token.value) >= 0,
    rating: (token, post) => post.rating === token.value,
    type: (token, post) => post.file_ext === token.value,

    width: (token, post) => FilterUtils.compare(post.width, token),
    height: (token, post) => FilterUtils.compare(post.height, token),
    filesize: (token, post) => FilterUtils.compare(post.size, token),

    score: (token, post) => FilterUtils.compare(post.score, token),
    favcount: (token, post) => FilterUtils.compare(post.fav_count, token),
    fav: (token, post) => post.is_favorited,

    uploader: (token, post) => FilterUtils.FilterTests.user(token, post),
    user: (token, post) => {
      // Funky userid: alternative
      if (token.value.startsWith("!"))
        return post.uploader_id === parseInt(token.value.substring(1));
      return post.uploader === token.value;
    },
    userid: (token, post) => FilterUtils.compare(post.uploader_id, token),
    username: (token, post) => post.uploader === token.value,

    pool: (token, post) => post.pools.includes(parseInt(token.value) || 0),
  },

  /**
   * Returns the filter type based on the metatag present in the input.
   * If none can be found, assumes that this is a regular tag instead.
   * @param {string} input
   * @returns
   */
  getFilterType: (input) => {
    input = input.toLowerCase();
    for (const key of Object.keys(FilterUtils.FilterTests))
      if (input.startsWith(key + ":")) return key;
    return "tag";
  },

  /**
   * Some people are incredibly strange and put comparisons backwards.
   * This makes sure that they get normalized regardless.
   */
  ComparisonTable: {
    "<=": "<=",
    "=<": "<=",
    ">=": ">=",
    "=>": ">=",
    "=": "=",
    "==": "=",
    "<": "<",
    ">": ">",
  },

  /**
   * Normalize the comparison type
   * @param {string} input Comparison string
   * @returns Normalized comparison string
   */
  getComparison: (input) => {
    if (/.+\.\..+/.test(input)) return "..";
    for (const [key, comparison] of Object.entries(FilterUtils.ComparisonTable))
      if (input.startsWith(key)) return comparison;
    return "=";
  },

  /**
   * Compare the provided value with the one listed in the token
   * @param {number} a Value to match against
   * @param {FilterToken} token Token to compare to
   * @returns true if the provided values pass the specified comparison type
   */
  compare: (a, token) => {
    switch (token.comparison) {
      case "=":
        return a == parseFloat(token.value);
      case "<":
        return a < parseFloat(token.value);
      case "<=":
        return a <= parseFloat(token.value);
      case ">":
        return a > parseFloat(token.value);
      case ">=":
        return a >= parseFloat(token.value);
      case "..": {
        const parts = token.value.split("..");
        if (parts.length !== 2) return false;

        const parsedParts = [];
        for (const el of parts) parsedParts.push(parseFloat(el));

        return a >= Math.min(...parsedParts) && a <= Math.max(...parsedParts);
      }
      default:
        return false;
    }
  },

  /**
   * Check if the post has the specified tag
   * @param {any} post
   * @param {string} filter
   * @returns true the post has the tag
   */
  tagsMatchesFilter: (post, filter) => {
    return post.tags.indexOf(filter) >= 0;
  },

  /**
   * Normalize the post rating
   * @param {string} input Rating text
   * @returns Rating letter
   */
  parseRating: (input) => {
    switch (input) {
      case "safe":
      case "s":
        return "s";
      case "questionable":
      case "q":
        return "q";
      case "explicit":
      case "e":
        return "e";
      default:
        return "x";
    }
  },

  /**
   * Takes in a formatted file size string (ex. 5MB) and converts it to bytes
   * @param {string} input Formatted string
   * @returns {number} Filesize, in bytes
   */
  parseFilesize: function (input) {
    if (!isNaN(Number(input))) return parseInt(input);

    for (const [index, size] of [/\db$/, /\dkb$/, /\dmb$/].entries()) {
      if (size.test(input)) return parseInt(input) * Math.pow(1024, index);
    }
    return 0;
  },
};
