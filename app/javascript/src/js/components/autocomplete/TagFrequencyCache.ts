interface TagFrequencyEntry {
  count: number;
  lastUsed: number;
}

interface TagFrequencyStore {
  entries: Record<string, TagFrequencyEntry>;
}

const STORAGE_KEY = "e6.autocomplete.tagfreq";
const PRUNE_DAYS = 90;
const MAX_ENTRIES = 500;

export default class TagFrequencyCache {
  private static _cache: TagFrequencyStore | null = null;

  static record (tag: string): void {
    const store = this.load();
    const prev = store.entries[tag];
    store.entries[tag] = {
      count: prev ? prev.count + 1 : 1,
      lastUsed: Date.now(),
    };
    this.prune(store);
    this.save(store);
  }

  static score (tag: string): number {
    const store = this.load();
    const entry = store.entries[tag];
    if (!entry) return 0;
    const daysSince = (Date.now() - entry.lastUsed) / 86_400_000;
    return (Math.log10(entry.count) + 1) / (1 + (daysSince / 30));
  }

  private static load (): TagFrequencyStore {
    if (this._cache !== null) return this._cache;
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      this._cache = raw ? JSON.parse(raw) : { entries: {} };
    } catch {
      return { entries: {} };
    }
    return this._cache;
  }

  private static save (store: TagFrequencyStore): void {
    this._cache = store;
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(store));
    } catch { /* quota exceeded or unavailable */ }
  }

  private static prune (store: TagFrequencyStore): void {
    const cutoff = Date.now() - (PRUNE_DAYS * 86_400_000);
    for (const key of Object.keys(store.entries)) {
      if (store.entries[key].lastUsed < cutoff)
        delete store.entries[key];
    }

    const keys = Object.keys(store.entries);
    if (keys.length > MAX_ENTRIES) {
      keys.sort((a, b) => store.entries[a].lastUsed - store.entries[b].lastUsed);
      for (const key of keys.slice(0, keys.length - MAX_ENTRIES))
        delete store.entries[key];
    }
  }
}
