import FilterToken from "./FilterToken";

/** Various utilities for the blacklist filters */
export default class FilterUtilities {

  /**
   * Tests for various filter types.
   * Each entry should return a `(token, post) => bool` function.
   */
  static FilterTests: Record<string, FilterTestFunction> = {
    tag: (token, post) => FilterUtilities.tagsMatchesFilter(post, token.value),
    tagcount: (token, post) => FilterUtilities.compare(post.tagcount, token),

    id: (token, post) => FilterUtilities.compare(post.id, token),
    status: (token, post) => post.flags.indexOf(token.value) >= 0,
    rating: (token, post) => post.rating === token.value,
    type: (token, post) => post.file_ext === token.value,

    width: (token, post) => FilterUtilities.compare(post.width, token),
    height: (token, post) => FilterUtilities.compare(post.height, token),
    filesize: (token, post) => FilterUtilities.compare(post.size, token),

    score: (token, post) => FilterUtilities.compare(post.score, token),
    favcount: (token, post) => FilterUtilities.compare(post.fav_count, token),
    fav: (_token, post) => post.is_favorited,

    uploader: (token, post) => FilterUtilities.FilterTests.user(token, post),
    user: (token, post) => {
    // Funky userid: alternative
    // TODO: Don't re-parse this on every run
      if (token.value.startsWith("!"))
        return post.uploader_id === parseInt(token.value.slice(1));
      return post.uploader === token.value;
    },
    userid: (token, post) => FilterUtilities.compare(post.uploader_id, token),
    username: (token, post) => post.uploader === token.value,

    pool: (token, post) => post.pools.includes(parseInt(token.value) || 0),

    // Not a supported metatag, type is assigned manually
    wildcard: (token, post) => FilterUtilities.wildcardTagMatchesFilter(post, token.value),
  };

  /** Array of supported metatags. */
  static FilterTypes = Object.keys(FilterUtilities.FilterTests);

  /**
   * Returns the filter type based on the metatag present in the input.
   * If none can be found, assumes that this is a regular tag instead.
   * @param {string} input Input string, should be lower case.
   * @returns
   */
  static getFilterType (input: string): string {
    const parts = input.split(":");
    if (parts.length == 1) return "tag";
    input = parts[0];

    for (const key of FilterUtilities.FilterTypes)
      if (input == key) return key;
    return "tag";
  }

  /**
   * Some people are incredibly strange and put comparisons backwards.
   * This makes sure that they get normalized regardless.
   */
  static ComparisonTable: Record<string, string> = {
    "<=": "<=",
    ">=": ">=",
    "=<": "<=",
    "=>": ">=",
    "<": "<",
    ">": ">",
  };

  /**
   * Normalize the comparison type
   * @param {string} input Comparison string
   * @returns Normalized comparison string
   */
  static getComparison (input: string): string {
    if (input.indexOf("..") != -1) return "..";
    const val = input.match(/^[<>=]{1,2}/);
    if (!val) return "=";
    return FilterUtilities.ComparisonTable[val[0]] || "=";
  }

  /**
   * Convert token value into the appropriate format.
   * @param {string} value Token value
   * @param {string} type Token type
   * @returns Normalized token value
   */
  static normalizeData (value: string, type: string): any {
    switch (type) {
      case "tag":
        return value;
      case "tagcount":
      case "id":
      case "width":
      case "height":
      case "score":
      case "favcount":
      case "userid":
        return parseInt(value);
      case "rating":
        return FilterUtilities.parseRating(value);
      case "filesize":
        return FilterUtilities.parseFilesize(value);
    }
    return value;
  }

  /**
   * Compare the provided value with the one listed in the token
   * @param {number} a Value to match against
   * @param {FilterToken} token Token to compare to
   * @returns true if the provided values pass the specified comparison type
   */
  static compare (a: number, token: FilterToken): boolean {
    switch (token.comparison) {
      case "=":
        return a == token.value;
      case "<":
        return a < token.value;
      case "<=":
        return a <= token.value;
      case ">":
        return a > token.value;
      case ">=":
        return a >= token.value;
      case "..":
        return a >= token.value[0] && a <= token.value[1];
    }
    return false;
  }

  /**
   * Check if the post has the specified tag
   * @param {any} post
   * @param {string} filter
   * @returns true the post has the tag
   */
  static tagsMatchesFilter (post, filter) {
    return post.tags.indexOf(filter) >= 0;
  }

  static wildcardTagMatchesFilter (post, filter) {
    for (const one of post.tags)
      if (filter.test(one)) return true;
    return false;
  }

  /**
   * Normalize the post rating
   * @param {string} input Rating text
   * @returns Rating letter
   */
  static parseRating (input: string): string {
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
  }

  /**
   * Takes in a formatted file size string (ex. 5MB) and converts it to bytes
   * @param {string} input Formatted string, needs to be lower case
   * @returns {number} Filesize, in bytes
   */
  static parseFilesize (input: string): number {
    if (/^\d+b?$/.test(input)) return parseInt(input);
    if (/^\d+kb$/.test(input)) return parseInt(input) * 1024;
    if (/^\d+mb$/.test(input)) return parseInt(input) * 1048576;
    return 0;
  }
}

type FilterTestFunction = (token: FilterToken, post: any) => boolean;
