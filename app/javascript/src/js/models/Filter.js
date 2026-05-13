import Blacklist from "@/core/blacklists";
import FilterUtils from "@/utility/filter_util";
import LStorage from "@/utility/storage";
import PostCache from "@/models/PostCache";
import Utility from "@/utility/utility";

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
  constructor (text) {
    this.text = text;
    this._enabled = !LStorage.Blacklist.FilterState.has(text);
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
  static create (text) {
    text = text.trim();

    // Get rid of comments
    if (!text || text.startsWith("#")) return null;
    text = text.toLowerCase().replace(/ #.*$/, "");

    return new Filter(text);
  }

  /** @returns {boolean} Filter state */
  get enabled () {
    return this._enabled;
  }

  set enabled (value) {
    this._enabled = value == true;

    if (this._enabled) LStorage.Blacklist.FilterState.delete(this.text);
    else LStorage.Blacklist.FilterState.add(this.text);

    for (const element of Blacklist.ui) element.rebuildFilters();
    Blacklist.update_visibility();
  }

  /**
   * Updates the filter with the provided post elements, adding or removing them from the matched IDs as necessary.
   * @param {JQuery<HTMLElement> | JQuery<HTMLElement>[]} $posts Thumbnail elements to update the filter with
   * @returns {boolean} True if any posts were updated, false otherwise
   */
  updateWithElements ($posts) {
    if (Array.isArray($posts)) {
      // Normal array – either produced by the branch below, or by PostCache.sample()
      if ($posts.length == 0) return false;
      let matchesAny = false;
      for (const post of $posts)
        if (this.updateWithElements($(post))) matchesAny = true;
      return matchesAny;
    } else if ($posts.length > 1) {
      // JQuery collection with multiple elements – produced by a normal jQuery selector
      return this.updateWithElements($posts.get().map(el => $(el)));
    }

    const post = PostCache.fromThumbnail($posts);
    if (!post) return false;
    return this.updateWithPosts(post);
  }

  /**
   * Updates the filter with the provided post(s), adding or removing them from the matched IDs as necessary.
   * @param {CachedPost | CachedPost[]} posts Post(s) to update the filter with
   * @returns {boolean} True if any posts were updated, false otherwise
   */
  updateWithPosts (posts) {
    if (Array.isArray(posts)) {
      if (posts.length == 0) return false;
      let matchesAny = false;
      for (const post of posts)
        if (this.updateWithPosts(post)) matchesAny = true;
      return matchesAny;
    }

    // Check if a post has already been matched
    if (this.matchIDs.has(posts.id)) return true;
    const post = posts;

    // Check if the post matches the filter
    let tokensMatch = true;
    if (this.tokens.length) {
      for (const token of this.tokens) {
        tokensMatch = token.test(post);
        if (!tokensMatch) break;
      }
    }

    // No need to check optional tokens if rest of don't match
    if (tokensMatch && this.optional.length) {
      let optionalTokensMatch = false;
      for (const token of this.optional) {
        optionalTokensMatch = token.test(post);
        if (optionalTokensMatch) break;
      }

      // If none of the optional tokens match, consider overall match a failure
      if (!optionalTokensMatch) tokensMatch = false;
    }

    if (tokensMatch === true) this.matchIDs.add(post.id);
    else if (tokensMatch === false) this.matchIDs.delete(post.id);

    return tokensMatch === true;
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
  constructor (raw) {
    raw = raw.trim().toLowerCase();

    // Token prefixes
    // TODO: This REQUIRES the tokens to be formatted properly.
    // -~ format is not accepted. This may cause issues with the the quick blacklist.
    // Regular blacklist edits do get fixed server-side.
    this.optional = raw.startsWith("~");
    if (this.optional) raw = raw.slice(1);

    this.inverted = raw.startsWith("-");
    if (this.inverted) raw = raw.slice(1);

    // Get filter type: tag, id, score, rating, etc.
    this.type = FilterUtils.getFilterType(raw);
    if (this.type !== "tag") raw = raw.slice(this.type.length + 1);
    else if (raw.includes("*")) {
      this.value = new RegExp(`^${Utility.regexp_escape(raw).replace(/\\\*/g, ".*")}$`);
      this.type = "wildcard";
      return;
    }

    // Get comparison methods: equals, smaller then, etc
    this.comparison = FilterUtils.getComparison(raw);
    if (this.comparison != "=" && this.comparison != "..")
      raw = raw.slice(this.comparison.length);

    // Normalize the value and deal with the range syntax
    if (this.comparison == "..") {
      if (raw.startsWith("..")) {
        this.comparison = "<=";
        this.value = FilterUtils.normalizeData(raw.slice(2), this.type);
      } else if (raw.endsWith("..")) {
        this.comparison = ">=";
        this.value = FilterUtils.normalizeData(raw.slice(0, -2), this.type);
      } else {
        let parts = raw.split("..");
        if (parts.length != 2) {
          this.comparison = "=";
          this.value = NaN;
        } else {
          this.value = [
            FilterUtils.normalizeData(parts[0], this.type),
            FilterUtils.normalizeData(parts[1], this.type),
          ];
        }
      }
    } else {
      this.value = FilterUtils.normalizeData(raw, this.type);
      if (this.comparison === "=" && this.type === "filesize") {
        // If the comparison uses direct equality, mirror the fudging behavior of
        // the filesize search metatag by changing the comparison to a range of
        // the initial value -5% and +5%.
        this.comparison = "..";
        this.value = [
          Math.trunc(this.value * 0.95),
          Math.trunc(this.value * 1.05),
        ];
      }
    }
  }

  /**
   * Checks if the filter token is applicable to the specified post
   * @param {any} post Post to test
   * @returns true if the filter token matches
   */
  test (post) {
    const val = FilterUtils.FilterTests[this.type](this, post);
    return this.inverted ? !val : val;
  }
}
