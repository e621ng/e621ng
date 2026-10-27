/**
 * Simple post cache, used to speed up blacklist processing.
 * Fetches data from the data-attributes of a thumbnail.
 *
 * Also tracks which thumbnail elements are on the page. A MutationObserver picks up
 * thumbnails as they are added, removed, or edited in place, so callers that touch
 * the DOM do not need to register or prune anything by hand.
 */
export default class PostCache {
  // Entries are never evicted on purpose: pages are full reloads, and each entry is tiny.
  // Element references are what `prune()` and the observer manage.
  private static _cache = new Map<number, CachedPostData>();

  private static _elements = new Map<number, Set<HTMLElement>>();
  private static _elementCount = 0;

  /** Elements the observer tracks. Avatar placeholders have no rating, so they are skipped. */
  public static readonly SELECTOR = "article.thumbnail[data-id][data-rating], #image-container[data-id]";
  private static readonly OBSERVED_ATTRIBUTES = ["data-tags", "data-rating", "data-flags"];

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
      tagSet: new Set(tags),
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
    this._emit("post:changed", { ids: [id] });
    return new CachedPost(value);
  }


  /* ============================== */
  /* ===== Element lifecycle ====== */
  /* ============================== */

  /**
   * Save post thumbnails so that they can be referred to later.
   * Normally done by the observer; only needed by hand when the result must be synchronous.
   * @param {JQuery<HTMLElement> | JQuery<HTMLElement>[]} $elements Post elements
   * @param {boolean} update Whether to re-read the attributes of already cached posts
   * @returns Elements that were not registered before
   */
  static register ($elements: JQuery<HTMLElement> | JQuery<HTMLElement>[], update: boolean = false): JQuery<HTMLElement>[] {
    const added: JQuery<HTMLElement>[] = [];
    for (let $post of $elements) {
      $post = $($post);
      const element = $post[0];
      if (!element) continue;

      const postData = PostCache.fromThumbnail($post, update);
      if (!postData) {
        // A thumbnail that cannot be parsed cannot be filtered, so it must not stay hidden
        $post.removeClass("blacklistable");
        continue;
      }

      let elements = this._elements.get(postData.id);
      if (!elements) {
        elements = new Set();
        this._elements.set(postData.id, elements);
      }
      if (elements.has(element)) continue;

      elements.add(element);
      this._elementCount++;
      added.push($post);
    }

    if (added.length) this._emit("post:added", { elements: added.map(($el) => $el[0]) });
    return added;
  }

  /**
   * Remove a thumbnail from the cache. Normally done by the observer when the element leaves the DOM.
   * @param {JQuery<HTMLElement>} $element Thumbnail element to remove
   * @returns Number of element references removed
   */
  static prune ($element: JQuery<HTMLElement> | JQuery<HTMLElement>[]): number {
    const list = Array.isArray($element) ? $element.map(($el) => $el[0]) : $element.get();
    const removedIDs: number[] = [];
    let removedCount = 0;

    for (const element of list) {
      const id = element ? parseInt(element.dataset.id) || 0 : 0;
      const elements = id ? this._elements.get(id) : null;
      if (!elements || !elements.delete(element)) continue;

      removedCount++;
      this._elementCount--;
      if (elements.size === 0) {
        this._elements.delete(id);
        removedIDs.push(id);
      }
    }

    if (removedIDs.length) this._emit("post:removed", { ids: removedIDs });
    return removedCount;
  }

  /**
   * Applies the provided function to all posts with the specified ID.
   * Typically used to set the blacklisted class on thumbnails.
   * @param {number} postID Post ID
   * @param {($el: JQuery<HTMLElement>) => void} fn Function to apply to the posts
   */
  static apply (postID: number, fn: ($el: JQuery<HTMLElement>) => void) {
    const elements = this._elements.get(postID);
    if (!elements) return;
    for (const one of elements)
      fn($(one));
  }

  /**
   * Returns an array containing one of every thumbnail elements
   * @returns {JQuery<HTMLElement>[]} Array of thumbnails
   */
  static sample (): JQuery<HTMLElement>[] {
    const output: JQuery<HTMLElement>[] = [];
    for (const elements of this._elements.values())
      output.push($(elements.values().next().value));
    return output;
  }

  /** IDs of posts that currently have at least one element on the page */
  static ids (): number[] {
    return Array.from(this._elements.keys());
  }

  /** IDs of every post with cached data, whether or not it is on the page */
  static cachedIDs (): number[] {
    return Array.from(this._cache.keys());
  }


  /* ============================== */
  /* ========== Observer ========== */
  /* ============================== */

  // Kept on a global symbol as well: specs reset the module registry, and the previous
  // module's observer would otherwise keep pruning into a map nobody reads anymore.
  private static readonly OBSERVER_KEY = Symbol.for("e621.postcache.observer");

  /**
   * Registers every tracked element under the root, then watches it for
   * thumbnails being added, removed, or edited. Safe to call more than once.
   * @param {Node} root Node to observe, the whole document by default
   */
  static observe (root: ParentNode & Node = document.documentElement): void {
    if (typeof MutationObserver === "undefined") return;
    this.disconnect();

    const found = root.querySelectorAll<HTMLElement>(this.SELECTOR);
    if (found.length) this.register(Array.from(found, (el) => $(el)));

    const observer = new MutationObserver((records) => this._onMutations(records));
    observer.observe(root, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: this.OBSERVED_ATTRIBUTES,
    });
    (window as any)[this.OBSERVER_KEY] = observer;
  }

  /** Stops watching the DOM. Already-registered elements are kept. */
  static disconnect (): void {
    const observer: MutationObserver | undefined = (window as any)[this.OBSERVER_KEY];
    if (!observer) return;
    observer.disconnect();
    delete (window as any)[this.OBSERVER_KEY];
  }

  private static _onMutations (records: MutationRecord[]): void {
    const removed = new Set<HTMLElement>();
    const added = new Set<HTMLElement>();
    const changed = new Set<HTMLElement>();

    const collect = (node: Node, into: Set<HTMLElement>) => {
      if (node.nodeType !== Node.ELEMENT_NODE) return;
      const element = node as HTMLElement;
      if (element.matches(this.SELECTOR)) into.add(element);
      for (const child of element.querySelectorAll<HTMLElement>(this.SELECTOR)) into.add(child);
    };

    for (const record of records) {
      if (record.type === "attributes") {
        const target = record.target as HTMLElement;
        if (target.matches(this.SELECTOR)) changed.add(target);
        continue;
      }
      for (const node of record.removedNodes) collect(node, removed);
      for (const node of record.addedNodes) collect(node, added);
    }

    // Moved elements show up in both lists; what matters is where they ended up
    const toPrune: JQuery<HTMLElement>[] = [];
    for (const element of removed)
      if (!element.isConnected) toPrune.push($(element));
    if (toPrune.length) this.prune(toPrune);

    const toRegister: JQuery<HTMLElement>[] = [];
    for (const element of added)
      if (element.isConnected) toRegister.push($(element));
    if (toRegister.length) this.register(toRegister);

    for (const element of changed) {
      if (!element.isConnected || added.has(element)) continue;
      const id = parseInt(element.dataset.id) || 0;
      if (!this._elements.has(id)) continue;
      this.fromThumbnail($(element), true);
    }
  }


  /* ============================== */
  /* =========== Events =========== */
  /* ============================== */

  private static _listeners = new Map<keyof PostCacheEvents, Set<PostCacheListener<any>>>();

  /**
   * Subscribes to a cache event.
   * @returns Function that removes the subscription
   */
  static on<K extends keyof PostCacheEvents> (event: K, fn: PostCacheListener<K>): () => void {
    let listeners = this._listeners.get(event);
    if (!listeners) {
      listeners = new Set();
      this._listeners.set(event, listeners);
    }
    listeners.add(fn);
    return () => this.off(event, fn);
  }

  static off<K extends keyof PostCacheEvents> (event: K, fn: PostCacheListener<K>): void {
    this._listeners.get(event)?.delete(fn);
  }

  private static _emit<K extends keyof PostCacheEvents> (event: K, detail: PostCacheEvents[K]): void {
    const listeners = this._listeners.get(event);
    if (!listeners) return;
    for (const fn of listeners) {
      try {
        fn(detail);
      } catch (error) {
        console.error(`PostCache: listener for ${event} failed`, error);
      }
    }
  }


  /* ============================== */
  /* ========== Lookups =========== */
  /* ============================== */

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

export interface PostCacheEvents {
  /** Elements registered for the first time */
  "post:added": { elements: HTMLElement[] };
  /** Posts whose last element left the page */
  "post:removed": { ids: number[] };
  /** Posts whose cached data was (re)written */
  "post:changed": { ids: number[] };
}

type PostCacheListener<K extends keyof PostCacheEvents> = (detail: PostCacheEvents[K]) => void;

export class CachedPost implements CachedPostData {

  public tag_string: string;
  public tags: string[];
  public tagSet: ReadonlySet<string>;
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
    // Copies, so that callers cannot mutate the cache through the arrays.
    // The tag set is read-only and shared, since it is what makes filtering cheap.
    this.tags = [...data.tags];
    this.flags = [...data.flags];
    this.pools = [...data.pools];
  }

  public hasTag (tag: string): boolean {
    return this.tagSet.has(tag);
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
  tagSet: ReadonlySet<string>,
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

// Module scripts run after the document is parsed, so the sweep sees server-rendered thumbnails.
// Must come after the class declarations above, since the sweep constructs CachedPost instances.
if (typeof document !== "undefined") PostCache.observe();
