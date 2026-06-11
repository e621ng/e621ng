// ========= Providers ========== //

export type AutocompleteProvider<T extends AutocompleteItem = AutocompleteItem> = (query: string) => Promise<T[]>;

// ===== Config & Functions ====== //

export type AutocompleteConfig = {
  searchFn: SearchFunction;
  insertFn: InsertFunction;
  renderFn: RenderFunction;
};

export type SearchFunction = (query: string, input: HTMLInputElement) => Promise<AutocompleteItem[]>;
export type InsertFunction = (input: HTMLInputElement, completion: string) => void;
export type RenderFunction = (li: HTMLLIElement, item: AutocompleteItem) => void;


// ======= Response Types ======= //

export interface AutocompleteItem {
  type: string;
  name: string;
  label: string;

  id?: number; // For users, pools, wikis
  post_count?: number; // For tags, artists, pools
}

export interface TagItem extends AutocompleteItem {
  type: "tag";

  category: number; // API returns the category ID
  post_count: number;
  antecedent: string | null;
};

export interface UserItem extends AutocompleteItem {
  type: "user";

  id: number;
  category: "user";
  level: string;
};

export interface PoolItem extends AutocompleteItem {
  type: "pool";

  id: number;
  category: "series" | "collection";
  post_count: number;
};

export interface ArtistItem extends AutocompleteItem {
  type: "artist";

  id: number;
  category: "artist";
  post_count: number;
};

export interface WikiItem extends AutocompleteItem {
  type: "wiki_page";

  id: number;
  category: number; // API returns the category ID
};

export interface StaticMetatagItem extends AutocompleteItem {
  type: "metatag",
  category: "metatag",
};

export type MetatagItem = StaticMetatagItem | UserItem | PoolItem | TagItem;
