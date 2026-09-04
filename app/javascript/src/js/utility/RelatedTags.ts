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
 * Rejects on failure (HTTP.postJSON throws on non-2xx) — callers decide.
 *
 * POST, not GET: the query is the full tag string, and a well-tagged post can
 * carry thousands of tags (20k+ characters) — far past URL/header limits.
 * Form-urlencoded so Rails reads params[:query]; CSRF added by the helper.
 */
export async function fetchRelatedTags (query: string, categoryId?: number): Promise<RelatedTagGroup[]> {
  const body = new URLSearchParams({ query });
  // != null keeps category 0 (general) while omitting the param for undefined.
  if (categoryId != null) body.set("category_id", String(categoryId));
  const data = await HTTP.postJSON<Record<string, RelatedTag[]>>("/related_tag/bulk.json", body);

  const groups: RelatedTagGroup[] = [];
  for (const [key, tags] of Object.entries(data)) {
    if (!tags.length) continue;
    groups.push({ title: "Related: " + key, tags: tags.sort(tagSorter) });
  }
  return groups;
}
