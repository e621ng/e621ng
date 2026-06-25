import E621Type from "@/interfaces/E621";
import PostCache, { CachedPost } from "@/models/PostCache";
import LStorage from "@/utility/storage/Local";
import FilterToken from "./FilterToken";

declare const E621: E621Type;

/**
 * Represents an individual line in the blacklist.
 * Contains one or more tokens, which are evaluated to
 * determine whether the post should be hidden.
 */
export default class Filter {

  /**
   * Creates a new Filter based on the provided text.
   * Normalizes the text before passing it on to the constructor,
   * and discards any lines that are guaranteed to be invalid.
   * @param {string} text Blacklist line
   * @returns Filter, or null if none was created
   */
  static create (text: string): Filter | null {
    text = text.trim();

    // Get rid of comments
    if (!text || text.startsWith("#")) return null;
    text = text.toLowerCase().replace(/ #.*$/, "");

    return new Filter(text);
  }

  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  public readonly text: string;
  public readonly matchIDs: Set<number>;
  public readonly tokens: FilterToken[];
  public readonly optional: FilterToken[];
  private _enabled: boolean;

  /**
   * Constructor. Should not normally be used – refer to `Filter.create()` instead.
   * Keep in mind that the input needs to be cleaned up beforehand:
   * - No comments, inline or standalone
   * - No trailing or leading whitespace
   * - No linebreaks
   * - All lowercase
   * @param {string} text Blacklist line
   */
  constructor (text: string) {
    this.text = text;
    this._enabled = !LStorage.Blacklist.FilterState.has(text);
    this.matchIDs = new Set();

    this.tokens = [];
    this.optional = [];

    // Tokenize the filter parts
    for (const word of new Set(this.text.split(" ").filter((e) => e.trim() !== ""))) {
      const token = new FilterToken(word);
      if (token.optional) this.optional.push(token);
      else this.tokens.push(token);
    }
  }


  /* ============================== */
  /* ========= Accessors ========== */
  /* ============================== */

  /** @returns {boolean} Filter state */
  public get enabled (): boolean {
    return this._enabled;
  }

  public set enabled (value: boolean) {
    this._enabled = value == true;

    if (this._enabled) LStorage.Blacklist.FilterState.delete(this.text);
    else LStorage.Blacklist.FilterState.add(this.text);

    E621.Blacklist.updatePostVisibility();
  }

  public setEnabledWithoutSaving (value: boolean) {
    this._enabled = value == true;
  }


  /* ============================== */
  /* ====== Instance Methods ====== */
  /* ============================== */

  /**
   * Updates the filter with the provided post elements, adding or removing them from the matched IDs as necessary.
   * @param {JQuery<HTMLElement> | JQuery<HTMLElement>[]} $posts Thumbnail elements to update the filter with
   * @returns {boolean} True if any posts were updated, false otherwise
   */
  updateWithElements ($posts: JQuery<HTMLElement> | JQuery<HTMLElement>[]): boolean {
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
  updateWithPosts (posts: CachedPost | CachedPost[]): boolean {
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
