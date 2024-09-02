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
  fav: (_token, post) => post.is_favorited,

  uploader: (token, post) => FilterUtils.FilterTests.user(token, post),
  user: (token, post) => {
    // Funky userid: alternative
    // TODO: Don't re-parse this on every run
    if (token.value.startsWith("!"))
      return post.uploader_id === parseInt(token.value.slice(1));
    return post.uploader === token.value;
  },
  userid: (token, post) => FilterUtils.compare(post.uploader_id, token),
  username: (token, post) => post.uploader === token.value,

  pool: (token, post) => post.pools.includes(parseInt(token.value) || 0),

  // Not a supported metatag, type is assigned manually
  wildcard: (token, post) => FilterUtils.wildcardTagMatchesFilter(post, token.value),
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
const ComparisonTable = {
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
FilterUtils.getComparison = (input) => {
  if (input.indexOf("..") != -1) return "..";
  const val = input.match(/^[<>=]{1,2}/);
  if (!val) return "=";
  return ComparisonTable[val[0]] || "=";
};

/**
 * Convert token value into the appropriate format.
 * @param {string} value Token value
 * @param {*} type Token type
 * @returns Normalized token value
 */
FilterUtils.normalizeData = (value, type) => {
  switch (type) {
    case "tag":
      return value;
    case "tagcount":
    case "id":
    case "width":
    case "height":
    case "score":
    case "favcout":
    case "userid":
      return parseInt(value);
    case "rating":
      return FilterUtils.parseRating(value);
    case "filesize":
      return FilterUtils.parseFilesize(value);
  }
  return value;
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

FilterUtils.wildcardTagMatchesFilter = (post, filter) => {
  for (const one of post.tags)
    if (filter.test(one)) return true;
  return false;
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
  if (/^\d+kb$/.test(input)) return parseInt(input) * 1024;
  if (/^\d+mb$/.test(input)) return parseInt(input) * 1048576;
  return 0;
};

export default FilterUtils;
