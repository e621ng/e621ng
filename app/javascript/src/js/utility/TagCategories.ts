export default class TagCategories {
  // Passed on from the back-end via a meta tag (TagCategory::CANONICAL_MAPPING).
  // Names are lowercased on ingest to match how the front-end refers to categories.
  private static readonly NAME_TO_ID: Record<string, number> = TagCategories.readMapping("tag-category-ids");
  private static readonly ID_TO_NAME: Record<number, string> = Object.fromEntries(
    Object.entries(TagCategories.NAME_TO_ID).map(([name, id]) => [id, name]),
  );

  /** The numeric id for a category name, case-insensitive; undefined if unknown. */
  static idFor (name: string): number | undefined {
    return TagCategories.NAME_TO_ID[name.toLowerCase()];
  }

  /** The lowercase canonical name for an id; "unknown" if absent. */
  static nameFor (id: number): string {
    return TagCategories.ID_TO_NAME[id] ?? "unknown";
  }

  /** The stylesheet class for an id. The stylesheet keys on the number, so this is readability only. */
  static cssClass (id: number): string {
    return `tag-type-${id}`;
  }

  private static readMapping (key: string): Record<string, number> {
    const element = document.querySelector(`meta[name="${key}"]`);
    if (!element) return {};
    try {
      const parsed = JSON.parse(element.getAttribute("content") || "{}");
      const result: Record<string, number> = {};
      for (const [name, id] of Object.entries(parsed))
        result[name.toLowerCase()] = id as number;
      return result;
    } catch {
      console.warn(`Failed to parse metadata for key "${key}".`);
      return {};
    }
  }
}
