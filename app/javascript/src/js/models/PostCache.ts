
/**
 * Simple post cache, used to speed up blacklist processing.
 * Fetches data from the data-attributes of a thumbnail.
 */
export default class PostCache {
  // Entries are never evicted on purpose: pages are full reloads, and each entry is tiny.
  // Element references are what `prune()` manages.
  private static _cache = new Map<number, CachedPostData>();

  private static _elements: { [key: number]: JQuery<HTMLElement>[] } = {};
  private static _elementCount = 0;

  /**
   * Add to cache based on the data-attributes of the specific thumbnail element
   * @param {JQuery<HTMLElement>} $element Thumbnail element
   * @param {boolean} update Whether to re-read the attributes if the post ID is already cached.
   * @returns Processed data
   */
  static fromThumbnail ($element: JQuery<HTMLElement>, update: boolean = false): CachedPost | null {
    const element = $element[0];
    if (!element) return null;

    // Reading the dataset directly is noticeably faster than $element.data()
    const data = element.dataset;
    const id = parseInt(data.id) || 0;
    if (!id) return null;
    if (!update && this._cache.has(id)) return this.get(id);

    return this._store(id, {
      tags: data.tags || "",
      flags: data.flags || "",
      pools: data.pools || "",
      rating: data.rating || "",
      file_ext: data.fileExt || "",

      width: parseInt(data.width) || -1,
      height: parseInt(data.height) || -1,
      size: parseInt(data.size) || -1,

      score: parseInt(data.score) || 0,
      fav_count: parseInt(data.favCount) || 0,
      is_favorited: data.isFavorited === "true",
      comment_count: parseInt(data.commentCount) || 0,

      uploader: data.uploader || "",
      uploader_id: parseInt(data.uploaderId) || -1,

      md5: data.md5 || "",
      preview_url: data.previewUrl || "",
      preview_webp: data.previewWebp || "",
      sample_url: data.sampleUrl || "",
      file_url: data.fileUrl || "",
    });
  }

  /**
   * Add to the cache based on the deferred post data
   * @param {number} id Post ID
   * @param {DeferredPostData} data Deferred post data
   * @param {boolean} update Whether to update the cache if the post ID is already present.
   * @returns Processed data
   */
  static fromDeferredPosts (id: number, data: DeferredPostData, update: boolean = false): CachedPost | null {
    if (!id) return null;
    if (!update && this._cache.has(id)) return this.get(id);

    return this._store(id, {
      tags: data.tags || "",
      flags: data.flags || "",
      pools: data.pools || "",
      rating: data.rating || "",
      file_ext: data.file_ext || "",

      width: data.width || -1,
      height: data.height || -1,
      size: data.size || -1,

      score: data.score || 0,
      fav_count: data.fav_count || 0,
      is_favorited: !!data.is_favorited,
      comment_count: data.comment_count || 0,

      uploader: data.uploader || "",
      uploader_id: data.uploader_id || -1,

      md5: data.md5 || "",
      preview_url: data.preview_url || "",
      preview_webp: data.preview_webp || "",
      sample_url: data.sample_url || "",
      file_url: data.file_url || "",
    });
  }

  /** Normalizes the raw values and writes them to the cache. Returns null if the rating is unusable. */
  private static _store (id: number, raw: RawPostData): CachedPost | null {
    const rating = raw.rating;
    if (rating !== "s" && rating !== "q" && rating !== "e") return null;

    const tags = splitWords(raw.tags);
    const pools: number[] = [];
    for (const one of splitWords(raw.pools)) {
      const parsed = parseInt(one);
      if (parsed) pools.push(parsed);
    }

    const value: CachedPostData = {
      id: id,
      tag_string: tags.join(" "),
      tags: tags,
      tagcount: tags.length,

      flags: splitWords(raw.flags),
      rating: rating,
      file_ext: raw.file_ext,

      width: raw.width,
      height: raw.height,
      size: raw.size,

      score: raw.score,
      fav_count: raw.fav_count,
      is_favorited: raw.is_favorited,
      comment_count: raw.comment_count,

      uploader: raw.uploader.toLowerCase(),
      uploader_id: raw.uploader_id,

      pools: pools,

      md5: raw.md5,
      preview_url: raw.preview_url,
      preview_webp: raw.preview_webp,
      sample_url: raw.sample_url,
      file_url: raw.file_url,
    };

    this._cache.set(id, value);
    return new CachedPost(value);
  }


  /**
   * Save post thumbnails so that they can be referred to later
   * @param {JQuery<HTMLElement> | JQuery<HTMLElement>[]} $elements Post elements
   * @param {boolean} update Whether to re-read the attributes of already cached posts
   */
  static register ($elements: JQuery<HTMLElement> | JQuery<HTMLElement>[], update: boolean = false): JQuery<HTMLElement>[] {
    const added: JQuery<HTMLElement>[] = [];
    for (let $post of $elements) {
      $post = $($post);
      // Stripped before validation on purpose: a thumbnail that cannot be parsed cannot be filtered either.
      $post.removeClass("blacklistable");
      const postData = PostCache.fromThumbnail($post, update);
      if (!postData) continue;

      if (!this._elements[postData.id])
        this._elements[postData.id] = [];

      // Check if this thumbnail element is already registered.
      const element = $post[0];
      if (this._elements[postData.id].some((one) => one[0] === element))
        continue;

      this._elements[postData.id].push($post);
      this._elementCount++;
      added.push($post);
    }
    return added;
  }

  /**
   * Remove a thumbnail from the cache. Should be called when a thumbnail is removed from the DOM to prevent memory leaks.
   * @param {JQuery<HTMLElement>} $element Thumbnail element to remove
   */
  static prune ($element: JQuery<HTMLElement> | JQuery<HTMLElement>[]): number {
    if (Array.isArray($element)) {
      let totalRemoved = 0;
      for (const el of $element) totalRemoved += this.prune(el);
      return totalRemoved;
    } else if ($element.length > 1) {
      return this.prune($element.get().map(el => $(el)));
    }

    const element = $element[0];
    const id = element ? parseInt(element.dataset.id) || 0 : 0;
    if (!id || !this._elements[id]) return 0;

    const initialLength = this._elements[id].length;
    this._elements[id] = this._elements[id].filter((one) => one[0] !== element);
    const removedCount = initialLength - this._elements[id].length;
    this._elementCount -= removedCount;

    // Cleanup to prevent .sample() from returning undefined values
    if (this._elements[id].length === 0) this._pruneElement(id);
    return removedCount;
  }

  /** Should only be called internally to remove all references to a post */
  private static _pruneElement (id: number) {
    delete this._elements[id];
  }


  /**
   * Applies the provided function to all posts with the specified ID.
   * Typically used to set the blacklisted class on thumbnails.
   * @param {number} postID Post ID
   * @param {($el: JQuery<HTMLElement>) => void} fn Function to apply to the posts
   */
  static apply (postID: number, fn: ($el: JQuery<HTMLElement>) => void) {
    if (!this._elements[postID]) return;
    for (const one of this._elements[postID])
      fn(one);
  }

  /**
   * Returns an array containing one of every thumbnail elements
   * @returns {JQuery<HTMLElement>[]} Array of thumbnails
   */
  static sample (): JQuery<HTMLElement>[] {
    const output: JQuery<HTMLElement>[] = [];
    for (const elements of Object.values(this._elements))
      output.push(elements[0]);
    return output;
  }

  /**
   * Gets the cached data for a post by its ID
   * @param postID Post ID
   * @returns {CachedPost | null} Cached post data or null if not found
   */
  static get (postID: number): CachedPost | null {
    const data = this._cache.get(postID);
    return data ? new CachedPost(data) : null;
  }

  /**
   * Gets the cached data for multiple posts by their IDs
   * @param postIDs Array of post IDs
   * @returns {{ [key: number]: CachedPost }} Object mapping post IDs to cached post data. If a post ID is not found, it will not be included in the output.
   */
  static getManyByID (postIDs: number[]): { [key: number]: CachedPost } {
    const posts: { [key: number]: CachedPost } = {};
    for (const postID of postIDs) {
      const post = this.get(postID);
      if (post) posts[postID] = post;
    }
    return posts;
  }

  static stats () {
    return {
      cachedPosts: this._cache.size,
      cachedElements: this._elementCount,
    };
  }
}

/** Splits a space-separated attribute into tokens, dropping empty ones. */
function splitWords (value: string): string[] {
  return value.trim().split(/\s+/).filter(Boolean);
}

export class CachedPost implements CachedPostData {

  public tag_string: string;
  public tags: string[];
  public tagcount: number;

  public id: number;
  public flags: string[];
  public rating: "s" | "q" | "e";
  public file_ext: string;

  public width: number;
  public height: number;
  public size: number;

  public score: number;
  public fav_count: number;
  public is_favorited: boolean;
  public comment_count: number;

  public uploader: string;
  public uploader_id: number;

  public pools: number[];

  public md5: string;
  public preview_url: string;
  public preview_webp: string;
  public sample_url: string;
  public file_url: string;

  constructor (data: CachedPostData) {
    Object.assign(this, data);
    // Copies, so that callers cannot mutate the cache through the arrays
    this.tags = [...data.tags];
    this.flags = [...data.flags];
    this.pools = [...data.pools];
  }

  public toAttributes (): { [key: string]: string | number | boolean } {
    return {
      "data-tags": this.tag_string,

      "data-id": this.id,
      "data-flags": this.flags.join(" "),
      "data-rating": this.rating,
      "data-file-ext": this.file_ext,

      "data-width": this.width,
      "data-height": this.height,
      "data-size": this.size,

      "data-score": this.score,
      "data-fav-count": this.fav_count,
      "data-is-favorited": this.is_favorited,
      "data-comment-count": this.comment_count,

      "data-uploader": this.uploader,
      "data-uploader-id": this.uploader_id,

      "data-pools": this.pools.join(" "),

      "data-md5": this.md5,
      "data-preview-url": this.preview_url,
      "data-preview-webp": this.preview_webp,
      "data-sample-url": this.sample_url,
      "data-file-url": this.file_url,
    };
  }

  public get ratingLong () {
    switch (this.rating) {
      case "s": return "safe";
      case "q": return "questionable";
      case "e": return "explicit";
      default: return "unknown";
    }
  }

  public get isPending () { return this.flags.includes("pending"); }
  public get isFlagged () { return this.flags.includes("flagged"); }
  public get isDeleted () { return this.flags.includes("deleted"); }

  // Post is likely blocked by safe mode, and returned no URLs
  public get isUnavailable () { return !this.preview_url; }
}

interface BasicPostData {
  id: number,

  rating: "s" | "q" | "e",

  width: number,
  height: number,
  size: number,
  file_ext: string,

  uploader: string,
  uploader_id: number,

  score: number,
  fav_count: number,
  is_favorited: boolean,
  comment_count: number,
}

/** Data produced by the server for deferred posts */
export interface DeferredPostData extends BasicPostData {
  tags: string,
  flags: string,
  pools: string,

  // Absent from deleted posts
  md5?: string,
  preview_url?: string,
  preview_webp?: string,
  sample_url?: string,
  file_url?: string,
}

/** Data stored in the cache for a post. URLs are normalized to empty strings when absent. */
export interface CachedPostData extends BasicPostData {
  tags: string[],
  tag_string: string,
  tagcount: number,

  flags: string[],
  pools: number[],

  md5: string,
  preview_url: string,
  preview_webp: string,
  sample_url: string,
  file_url: string,
}

/** Raw field values shared by both parsers, before normalization */
interface RawPostData {
  tags: string,
  flags: string,
  pools: string,
  rating: string,
  file_ext: string,

  width: number,
  height: number,
  size: number,

  score: number,
  fav_count: number,
  is_favorited: boolean,
  comment_count: number,

  uploader: string,
  uploader_id: number,

  md5: string,
  preview_url: string,
  preview_webp: string,
  sample_url: string,
  file_url: string,
}
