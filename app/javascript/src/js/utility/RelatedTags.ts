import HTTP from "@/utility/HTTP";
import { tagSorter } from "@/pages/uploads/new/tag_field.js";

// Shared transport + response shaping for the related-tags lookup, consumed by
// both uploads#new (uploader.vue) and posts#show (tag_editor.vue). Orchestration
// state (loading flag, re-entry guard, toggle-off, panel expansion) stays in the
// components — this module only fetches and shapes.

export interface RelatedTag {
  name: string;
  category_id: number;
}

export interface RelatedTagGroup {
  title: string;
  tags: RelatedTag[];
}

/** The selected substring of a text field, or null when nothing is selected. */
export function selectedText (field: HTMLTextAreaElement | HTMLInputElement): string | null {
  const length = (field.selectionEnd ?? 0) - (field.selectionStart ?? 0);
  if (!length) return null;
  return field.value.slice(field.selectionStart!, field.selectionEnd!);
}

/**
 * Query the bulk related-tags endpoint and shape the response for display:
 * empty groups are dropped, tags sort by name, titles become "Related: <key>".
 * Rejects on failure (HTTP.getJSON throws on non-2xx) — callers decide.
 */
export async function fetchRelatedTags (query: string, categoryId?: number): Promise<RelatedTagGroup[]> {
  const params: Record<string, string | number> = { query };
  // != null keeps category 0 (general) while omitting the param for undefined.
  if (categoryId != null) params["category_id"] = categoryId;
  const data = await HTTP.getJSON<Record<string, RelatedTag[]>>("/related_tag/bulk.json", params);

  const groups: RelatedTagGroup[] = [];
  for (const [key, tags] of Object.entries(data)) {
    if (!tags.length) continue;
    groups.push({ title: "Related: " + key, tags: tags.sort(tagSorter) });
  }
  return groups;
}
