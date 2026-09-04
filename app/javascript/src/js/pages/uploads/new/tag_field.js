// Shared helpers for the free-text tag sources (the "Other Tags" sink, the
// per-category textareas, and the artist field). A field's value is a
// space-separated string; its contribution is the clean token list.

export function splitTags (value) {
  return (value || "").trim().split(/\s+/).filter(Boolean);
}

// Append tags (deduped) and keep the trailing space the inputs rely on.
export function addTags (value, tags) {
  const existing = splitTags(value);
  for (const tag of tags) if (!existing.includes(tag)) existing.push(tag);
  return existing.join(" ") + " ";
}

// Remove a tag; returns the value unchanged when the tag is absent.
export function removeTag (value, tag) {
  const tags = splitTags(value);
  const idx = tags.indexOf(tag);
  if (idx === -1) return value;
  tags.splice(idx, 1);
  return tags.join(" ") + " ";
}

// Order tag objects by name, for the related-tags display.
export function tagSorter (a, b) {
  return a.name > b.name ? 1 : -1;
}
