// A tag row in the related-tags panel (Quick Tags / Recent / server groups).
export interface RelatedTag {
  name: string;
  category_id: number;
}

// One titled group of related tags, as shaped by related_tags.ts.
export interface RelatedTagGroup {
  title: string;
  tags: RelatedTag[];
}

// Shape of a tag record in the upload/edit tag preview (server /tags/preview.json
// rows, plus the id:-1 placeholder for unknown input and the derived flags).
export interface PreviewTag {
  id: number | null;          // null → "new" badge; -1 → unknown-input placeholder
  name: string;
  category: number;
  alias?: string;
  resolved?: string;
  implies?: string[];         // server-provided
  impliedBy?: string[];       // derived in tag_preview
  duplicate?: boolean;        // derived in tag_preview
  post_count?: number;
}
