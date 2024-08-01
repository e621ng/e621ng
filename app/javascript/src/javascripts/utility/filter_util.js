/** Various utilities for the blacklist filters */
let FilterUtils = {};

/**
 * Tests for various filter types.
 * Each entry should return a `(token, post) => bool` function.
 */
FilterUtils.FilterTests = {
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
};

/** Array of supported metatags. */
const FilterTypes = Object.keys(FilterUtils.FilterTests);

/**
 * Returns the filter type based on the metatag present in the input.
 * If none can be found, assumes that this is a regular tag instead.
 * @param {string} input Input string, should be lower case.
 * @returns
 */
FilterUtils.getFilterType = (input) => {
  input = input.split(":");
  if (input.length == 1) return "tag";
  input = input[0];

  for (const key of FilterTypes)
    if (input == key) return key;
  return "tag";
};

/**
 * Some people are incredibly strange and put comparisons backwards.
 * This makes sure that they get normalized regardless.
 */
const ComparisonTable = Object.entries({
  "<": "<",
  ">": ">",
  "<=": "<=",
  ">=": ">=",
  "=<": "<=",
  "=>": ">=",
  "=": "=",
  "==": "=",
});

/**
 * Normalize the comparison type
 * @param {string} input Comparison string
 * @returns Normalized comparison string
 */
FilterUtils.getComparison = (input) => {
  if (input.indexOf("..") != -1) return "..";
  for (const [key, comparison] of ComparisonTable)
    if (input.startsWith(key)) return comparison;
  return "=";
};

/**
 * Compare the provided value with the one listed in the token
 * @param {number} a Value to match against
 * @param {FilterToken} token Token to compare to
 * @returns true if the provided values pass the specified comparison type
 */
FilterUtils.compare = (a, token) => {
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
};

/**
 * Check if the post has the specified tag
 * @param {any} post
 * @param {string} filter
 * @returns true the post has the tag
 */
FilterUtils.tagsMatchesFilter = (post, filter) => {
  return post.tags.indexOf(filter) >= 0;
};

/**
   * Normalize the post rating
   * @param {string} input Rating text
   * @returns Rating letter
   */
FilterUtils.parseRating = (input) => {
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
 * @param {string} input Formatted string, needs to be lower case
 * @returns {number} Filesize, in bytes
 */
FilterUtils.parseFilesize = function (input) {
  if (/^\d+b?$/.test(input)) return parseInt(input);
  if (/^\d+mb$/.test(input)) return parseInt(input) * 1048576;
  if (/^\d+kb$/.test(input)) return parseInt(input) * 1024;
  return 0;
};

export default FilterUtils;