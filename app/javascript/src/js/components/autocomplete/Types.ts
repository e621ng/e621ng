// ========== Finders =========== //

export type AutocompleteFinder<T extends AutocompleteItem = AutocompleteItem> = (query: string) => Promise<T[]>;


// ======= Response Types ======= //

export interface AutocompleteItem {
  type: string;
  name: string;
  label: string;

  id?: number; // users, pools, wikis
  post_count?: number; // tags, artists, pools
  category?: number | string; // tags, pools, wiki
  antecedent?: string | null; // tags
  level?: string; // users
}

export interface TagItem extends AutocompleteItem {
  category: number; // API returns the category ID
  post_count: number;
  antecedent: string | null;
}

export interface UserItem extends AutocompleteItem {
  id: number;
  level: string;
}

export interface PoolItem extends AutocompleteItem {
  id: number;
  category: "series" | "collection";
  post_count: number;
}

export interface ArtistItem extends AutocompleteItem {
  id: number;
  post_count: number;
}

export interface WikiItem extends AutocompleteItem {
  id: number;
  category: number; // API returns the category ID
}

export interface StaticMetatagItem extends AutocompleteItem {
  category: "metatag";
}
