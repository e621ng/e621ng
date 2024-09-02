/**
 * Simple post cache, used to speed up blacklist processing.
 * Fetches data from the data-attributes of a thumbnail.
 */
export default class PostCache {
  static _cache = {};

  static _elements = {};


  /**
   * Add to cache based on the data-attributes of the specific thumbnail element
   * @param {JQuery<HTMLElement>} $element Thumbnail element
   * @returns Processed data
   */
  static fromThumbnail ($element) {
    const id = $element.data("id");
    if (this._cache[id]) return this._cache[id];

    // As of right now, the code below will take up three
    // times as long to execute compared to simply fetching
    // the data from cache. While understandable, it should
    // still be optimized wherever possible.

    const data = $element[0].dataset; // Faster than $element.data()

    // For some reason, this takes 10x as long on the first post.
    // But it's still only ~1ms (rather than 0.1ms), so it's fine
    const tag_string = data.tags || "",
      tags = tag_string.split(" ");

    const pools = [];
    for (let value of (data.pools + "").split(" ")) {
      value = parseInt(value);
      if (value) pools.push(value);
    }

    const value = {
      tag_string: tag_string,
      tags: tags,
      tagcount: tags.length,

      id: parseInt(data.id),
      flags: (data.flags || "").split(" "),
      rating: data.rating || "",
      file_ext: data.fileExt || "",

      width: parseInt(data.width) || -1,
      height: parseInt(data.height) || -1,
      size: parseInt(data.size) || -1,

      score: parseInt(data.score) || 0,
      fav_count: parseInt(data.favCount) || 0,
      is_favorited: data.isFavorited === "true",

      uploader: (data.uploader || "").toLowerCase(),
      uploader_id: parseInt(data.uploaderId) || -1,

      pools: pools,
    };

    this._cache[id] = value;
    return value;
  }


  /**
   * Add to the cache based on the deferred post data
   * @param {number} id Post ID
   * @param {any} data Deferred post data
   * @returns Processed data
   */
  static fromDeferredPosts (id, data) {

    // Likely won't happen, but won't hurt to check
    if (!id) return null;
    if (this._cache[id]) return this._cache[id];

    const tag_string = data.tags || "",
      tags = tag_string.split(" ");

    const value = {
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

      uploader: (data.uploader || "").toLowerCase(),
      uploader_id: parseInt(data.uploader_id) || -1,

      pools: data.pools,
    };

    this._cache[id] = value;
    return value;
  }


  /**
   * Save post thumbnails so that they can be referred to later
   * @param {JQuery<HTMLElement> | JQuery<HTMLElement>[]} $element Post elements
   */
  static register ($elements) {
    for (let $post of $elements) {
      $post = $($post);
      $post.removeClass("blacklistable");
      const postData = PostCache.fromThumbnail($post);

      if (!this._elements[postData.id]) this._elements[postData.id] = [];
      this._elements[postData.id].push($post);
    }
  }


  /**
   * Applies the provided function to all posts with the specified ID.
   * Typically used to set the blacklisted class on thumbnails.
   * @param {number} postID Post ID
   * @param {($el: JQuery<HTMLElement>) => void} fn Function to apply to the posts
   */
  static apply (postID, fn) {
    for (const one of this._elements[postID])
      fn(one);
  }

  /**
   * Returns an array containing one of every thumbnail elements
   * @returns {JQuery<HTMLElement>[]} Array of thumbnails
   */
  static sample () {
    const output = [];
    for (const elements of Object.values(this._elements))
      output.push(elements[0]);
    return output;
  }
}
