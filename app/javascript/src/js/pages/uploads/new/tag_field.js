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

// Grouped variants for the post-show tag editor, whose value keeps the
// newline-per-category grouping of categorized_tag_list_text. The flat helpers
// above would eat the newlines (splitTags splits on all whitespace).

// Append a tag unless already present anywhere (case-insensitive), preserving
// the existing text verbatim; keeps the trailing-space convention.
export function addTagGrouped (value, tag) {
  if (splitTags(value.toLowerCase()).includes(tag.toLowerCase())) return value;
  let out = value;
  if (out.length && out[out.length - 1] !== " ") out += " ";
  return out + tag + " ";
}

// Remove every case-insensitive occurrence of a tag from a newline-grouped
// value. Only lines containing it are rewritten (tokens rejoined with single
// spaces); other lines and all casing are preserved. Value unchanged if absent.
export function removeTagGrouped (value, tag) {
  const target = tag.toLowerCase();
  let removed = false;
  const lines = value.split(/\r?\n|\r/g).map((line) => {
    const tokens = splitTags(line);
    const kept = tokens.filter((t) => t.toLowerCase() !== target);
    if (kept.length === tokens.length) return line;
    removed = true;
    return kept.join(" ");
  });
  if (!removed) return value;
  const joined = lines.join("\n");
  return joined.endsWith(" ") ? joined : joined + " ";
}
