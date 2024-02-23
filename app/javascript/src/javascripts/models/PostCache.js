/**
 * Simple post cache, used to speed up blacklist processing.  
 * Fetches data from the data-attributes of a thumbnail.
 */
export default class PostCache {
  static _cache = {};

  static fromThumbnail($element) {
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

      id: data.id,
      flags: (data.flags || "").split(" "),
      rating: data.rating || "",
      file_ext: data.fileExt || "",

      width: data.width || -1,
      height: data.height || -1,
      size: data.size || -1,

      score: data.score || 0,
      fav_count: data.favCount || 0,
      is_favorited: data.isFavorited,

      uploader: (data.uploader || "").toLowerCase(),
      uploader_id: data.uploaderId || -1,

      pools: pools,
    };

    this._cache[id] = value;
    return value;
  }
}
