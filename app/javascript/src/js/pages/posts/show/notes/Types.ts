export interface Point {
  x: number;
  y: number;
}

export interface Size {
  width: number;
  height: number;
}

export type Rect = Point & Size;

/** Constructor input for a Note. Geometry is in original-image pixels. */
export interface NoteInit extends Rect {
  id: string;
  content: string;
  html: string;
}

export type NoteSnapshot = NoteInit;

/** Parsed form of the double-encoded `note` string returned by notes#create / notes#update */
export interface NoteServerAttributes extends Rect {
  id: number;
  post_id: number;
  body: string;
  creator_id?: number;
  creator_name?: string;
  is_active?: boolean;
  version?: number;
  created_at?: string;
  updated_at?: string;
}

/** Deferred post payload consumed by DeferredPostLoader via `e621:add_deferred_posts` */
export type DeferredPosts = Record<number, unknown>;

export interface NoteSaveResponse {
  note: string;
  dtext: string;
  posts?: DeferredPosts;
}

export interface DTextPreviewResponse {
  html: string;
  posts?: DeferredPosts;
}

export interface NoteErrorResponse {
  success?: boolean;
  reasons?: string[];
  reason?: string;
}

export type ResizeHandle = "nw" | "se";
