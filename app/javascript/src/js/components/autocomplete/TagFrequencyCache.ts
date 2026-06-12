const STORAGE_KEY = "e6.posts.acache.store";
const PRUNE_DAYS = 90;
const MAX_ENTRIES = 500;

export default class TagFrequencyCache {

  // ========= Public API ========= //

  /**
   * Records the usage of a tag, incrementing its count and updating its last used timestamp.
   * @param tag The name of the tag to record usage for
   */
  static record (tag: string): void {
    const store = this.cache;
    const prev = store[tag];
    store[tag] = {
      count: prev ? prev.count + 1 : 1,
      lastUsed: Date.now(),
    };
    this.save();
  }

  /**
   * Computes a score for a tag based on its usage frequency and recency, used for sorting autocomplete results.
   * @param tag The name of the tag to compute the score for
   * @returns A numeric score representing the tag's relevance, where higher scores indicate more frequently and recently used tags
   */
  static score (tag: string): number {
    const store = this.cache;
    const entry = store[tag];
    if (!entry) return 0;
    const daysSince = (Date.now() - entry.lastUsed) / 86_400_000;
    return (Math.log10(entry.count) + 1) / (1 + (daysSince / 30));
  }


  // ====== Cache Management ====== //

  private static _cache: TagFrequencyStore | null = null;

  private static get cache (): TagFrequencyStore {
    if (this._cache === null) {
      try { // Load cache from localStorage
        const raw = localStorage.getItem(STORAGE_KEY);
        this._cache = raw ? JSON.parse(raw) : {};
      } catch { this._cache = {}; }

      this.prune(); // Prune old data on load
    }
    return this._cache;
  }

  private static save (): void {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(this.cache));
    } catch { /* quota exceeded or unavailable */ }
  }

  private static prune (): void {
    const cache = this.cache; // Ensure cache is loaded

    const cutoff = Date.now() - (PRUNE_DAYS * 86_400_000);
    const entryCount = Object.keys(cache).length;
    if (entryCount === 0) return;

    // Prune old entries
    for (const [key, value] of Object.entries(cache)) {
      if (value.lastUsed < cutoff) delete cache[key];
    }

    // Prune least recently used if over max entries
    const keys = Object.keys(cache);
    if (keys.length > MAX_ENTRIES) {
      keys.sort((a, b) => cache[a].lastUsed - cache[b].lastUsed);
      for (const key of keys.slice(0, keys.length - MAX_ENTRIES))
        delete cache[key];
    }

    if (entryCount === Object.keys(cache).length)
      return; // No change, skip save

    this.save();
  }
}

type TagFrequencyStore = Record<string, TagFrequencyEntry>;

interface TagFrequencyEntry {
  count: number;
  lastUsed: number;
}
