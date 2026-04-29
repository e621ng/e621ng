
/**
 * Simple post cache, used to speed up blacklist processing.
 * Fetches data from the data-attributes of a thumbnail.
 */
export default class PostCache {
  static _cache: { [key: number]: RawPostData } = {};
  static _index = new Set<number>();

  static _elements: { [key: number]: JQuery<HTMLElement>[] } = {};
  static _elementCount = 0;

  /**
   * Add to cache based on the data-attributes of the specific thumbnail element
   * @param {JQuery<HTMLElement>} $element Thumbnail element
   * @returns Processed data
   */
  static fromThumbnail ($element: JQuery<HTMLElement>): CachedPost | null {
    const id = $element.data("id");
    if (!id) return null;
    if (this._index.has(id)) return new CachedPost(this._cache[id]);

    // As of right now, fetching post data from the attributes takes up to three times as long
    // compared to getting it from the cache. As such, it should be avoided whenever possible.

    const data = $element[0].dataset; // Faster than $element.data()

    // For some reason, this takes 10x as long on the first post.
    // But it's still only ~1ms (rather than 0.1ms), so it's fine
    const tag_string = data.tags || "",
      tags = tag_string.split(" ");

    const pools = [];
    for (const one of (data.pools + "").split(" ")) {
      const parsedOne = parseInt(one);
      if (parsedOne) pools.push(parsedOne);
    }

    const value: RawPostData = {
      tag_string: tag_string,
      tags: tags,
      tagcount: tags.length,

      id: id,
      flags: (data.flags || "").split(" "),
      rating: data.rating || "",
      file_ext: data.fileExt || "",

      width: parseInt(data.width) || -1,
      height: parseInt(data.height) || -1,
      size: parseInt(data.size) || -1,

      score: parseInt(data.score) || 0,
      fav_count: parseInt(data.favCount) || 0,
      is_favorited: data.isFavorited === "true",
      comment_count: parseInt(data.commentCount) || 0,

      uploader: (data.uploader || "").toLowerCase(),
      uploader_id: parseInt(data.uploaderId) || -1,

      pools: pools,

      md5: data.md5 || "",
      preview_url: data.previewUrl || "",
      preview_webp: data.previewWebp || "",
      sample_url: data.sampleUrl || "",
      file_url: data.fileUrl || "",
    };

    this._cache[id] = value;
    this._index.add(id);
    return new CachedPost(value);
  }

  /**
   * Add to the cache based on the deferred post data
   * @param {number} id Post ID
   * @param {any} data Deferred post data
   * @returns Processed data
   */
  static fromDeferredPosts (id: number, data: any): CachedPost | null {
    if (!id) return null;
    if (this._index.has(id)) return new CachedPost(this._cache[id]);

    // For some reason, this takes 10x as long on the first post.
    // But it's still only ~1ms (rather than 0.1ms), so it's fine
    const tag_string = data.tags || "",
      tags = tag_string.split(" ");

    const pools = [];
    for (const one of (data.pools + "").split(" ")) {
      const parsedOne = parseInt(one);
      // NOTE: Will now work for a pool with ID 0
      if (Number.isFinite(parsedOne)) pools.push(parsedOne);
    }

    const value: RawPostData = {
      tag_string: tag_string,
      tags: tags,
      tagcount: tags.length,

      id: id,
      flags: (data.flags || "").split(" "),
      rating: data.rating || "",
      file_ext: data.file_ext || "",

      width: parseInt(data.width) || -1,
      height: parseInt(data.height) || -1,
      size: parseInt(data.size) || -1,

      score: parseInt(data.score) || 0,
      fav_count: parseInt(data.fav_count) || 0,
      is_favorited: data.is_favorited === "true",
      comment_count: parseInt(data.comment_count) || 0,

      uploader: (data.uploader || "").toLowerCase(),
      uploader_id: parseInt(data.uploader_id) || -1,

      pools: pools,

      md5: data.md5 || "",
      preview_url: data.preview_url || "",
      preview_webp: data.preview_webp || "",
      sample_url: data.sample_url || "",
      file_url: data.file_url || "",
    };

    this._cache[id] = value;
    this._index.add(id);
    return new CachedPost(value);
  }


  /**
   * Save post thumbnails so that they can be referred to later
   * @param {JQuery<HTMLElement> | JQuery<HTMLElement>[]} $elements Post elements
   */
  static register ($elements: JQuery<HTMLElement> | JQuery<HTMLElement>[]) {
    for (let $post of $elements) {
      $post = $($post);
      $post.removeClass("blacklistable");
      const postData = PostCache.fromThumbnail($post);
      if (!postData) continue; // .fromThumbnail returns null if it cannot parse the thumbnail data

      if (!this._elements[postData.id]) this._elements[postData.id] = [];
      this._elements[postData.id].push($post);
      this._elementCount++;
    }
  }

  /**
   * Remove a thumbnail from the cache. Should be called when a thumbnail is removed from the DOM to prevent memory leaks.
   * @param {JQuery<HTMLElement>} $element Thumbnail element to remove
   */
  static prune ($element: JQuery<HTMLElement>) {
    const id = $element.data("id");
    if (!id) return;
    if (!this._elements[id]) return;

    this._elements[id] = this._elements[id].filter((one: JQuery<HTMLElement>) => !one.is($element));
    this._elementCount--;
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
    const output = [];
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
    if (!this._index.has(postID)) return null;
    return new CachedPost(this._cache[postID]);
  }

  /**
   * Gets the cached data for multiple posts by their IDs
   * @param postIDs Array of post IDs
   * @returns {{ [key: number]: CachedPost }} Object mapping post IDs to cached post data. If a post ID is not found, it will not be included in the output.
   */
  static getManyByID (postIDs: number[]): { [key: number]: CachedPost } {
    const posts: { [key: number]: CachedPost } = {};
    for (const postID of new Set(postIDs)) {
      const post = this.get(postID);
      if (post) posts[postID] = post;
    }
    return posts;
  }

  static stats () {
    return {
      cachedPosts: this._index.size,
      cachedElements: this._elementCount,
    };
  }
}

export class CachedPost implements RawPostData {

  public tag_string: string;
  public tags: string[];
  public tagcount: number;

  public id: number;
  public flags: string[];
  public rating: string;
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

  public md5?: string;
  public preview_url?: string;
  public preview_webp?: string;
  public sample_url?: string;
  public file_url?: string;

  constructor (data: RawPostData) {
    for (const [key, value] of Object.entries(data))
      this[key] = value;
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
}

type RawPostData = {
  tag_string: string,
  tags: string[],
  tagcount: number,

  id: number,
  flags: string[],
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

  pools: number[],

  // Absent from deleted posts
  md5?: string,
  preview_url?: string,
  preview_webp?: string,
  sample_url?: string,
  file_url?: string,
};
