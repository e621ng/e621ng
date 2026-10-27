import { CachedPost } from "@/models/PostCache";
import LStorage from "@/utility/storage/Local";
import FilterToken from "./FilterToken";

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

  /** Called after the filter is toggled on or off. Set by the Blacklist. */
  public onChange: (() => void) | null = null;

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

    this.onChange?.();
  }

  public setEnabledWithoutSaving (value: boolean) {
    this._enabled = value == true;
  }


  /* ============================== */
  /* ====== Instance Methods ====== */
  /* ============================== */

  /**
   * Checks whether the post matches this filter. Does not touch the matched IDs.
   * @param {CachedPost} post Post to test
   */
  test (post: CachedPost): boolean {
    for (const token of this.tokens)
      if (!token.test(post)) return false;

    if (!this.optional.length) return true;
    for (const token of this.optional)
      if (token.test(post)) return true;
    return false;
  }

  /**
   * Re-evaluates the provided post(s), adding or removing them from the matched IDs as necessary.
   * @param {CachedPost | CachedPost[]} posts Post(s) to update the filter with
   * @returns {boolean} True if any of the posts match
   */
  updateWithPosts (posts: CachedPost | CachedPost[]): boolean {
    if (Array.isArray(posts)) {
      let matchesAny = false;
      for (const post of posts)
        if (this.updateWithPosts(post)) matchesAny = true;
      return matchesAny;
    }

    const matches = this.test(posts);
    if (matches) this.matchIDs.add(posts.id);
    else this.matchIDs.delete(posts.id);
    return matches;
  }

  /** Drops the post from the matched IDs, e.g. once it left the page. */
  forget (id: number): void {
    this.matchIDs.delete(id);
  }
}
