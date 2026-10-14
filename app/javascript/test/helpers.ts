// Encodes a value the same way the back-end ships it: UTF-8 bytes -> base64,
// matching the decode in Settings.ts / CurrentUser.ts
// (Uint8Array.from(atob(x), c => c.charCodeAt(0)) -> TextDecoder).
function encodeBase64 (value: unknown): string {
  const bytes = new TextEncoder().encode(JSON.stringify(value));
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

/**
 * Inject a `<script id="...">` element holding base64-encoded JSON, as the
 * server-rendered page does for `site-settings` and `site-user`.
 */
export function setSiteData (id: string, value: unknown): void {
  let script = document.getElementById(id);
  if (!script) {
    script = document.createElement("script");
    script.id = id;
    // Non-executable type so jsdom leaves the payload as inert text, matching
    // how the server ships this data. Settings/CurrentUser read textContent.
    (script as HTMLScriptElement).type = "application/json";
    document.body.appendChild(script);
  }
  script.textContent = encodeBase64(value);
}

/** Inject or update a `<meta name="..." content="...">` element in the head. */
export function setMeta (name: string, content: string): void {
  let meta = document.head.querySelector<HTMLMetaElement>(`meta[name="${name}"]`);
  if (!meta) {
    meta = document.createElement("meta");
    meta.name = name;
    document.head.appendChild(meta);
  }
  meta.setAttribute("content", content);
}

/** Remove a `<meta name="...">` element, if present. */
export function removeMeta (name: string): void {
  document.head.querySelector(`meta[name="${name}"]`)?.remove();
}

// Canonical tag-category id map (TagCategory::CANONICAL_MAPPING). The back-end emits
// this as the `tag-category-ids` meta on every page, so the harness seeds it globally.
export const TAG_CATEGORY_IDS: Record<string, number> = {
  General: 0, Artist: 1, Contributor: 2, Copyright: 3, Character: 4,
  Species: 5, Invalid: 6, Meta: 7, Lore: 8,
};

/** Seed the ambient `tag-category-ids` meta (mirrors _head.html.erb). */
export function setTagCategoryMeta (): void {
  setMeta("tag-category-ids", JSON.stringify(TAG_CATEGORY_IDS));
}

/**
 * A duck-typed fetch Response for mocking `globalThis.fetch`. Only the surface the
 * uploader consumes: ok/status, case-insensitive headers.get, json(), text().
 */
export function jsonResponse (
  body: unknown,
  { status = 200, headers = {} }: { status?: number, headers?: Record<string, string> } = {},
): any {
  const lower = new Map(Object.entries(headers).map(([k, v]) => [k.toLowerCase(), v]));
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: { get: (name: string) => lower.get(String(name).toLowerCase()) ?? null },
    json: async () => body,
    text: async () => (typeof body === "string" ? body : JSON.stringify(body)),
  };
}

/**
 * A duck-typed non-JSON response (e.g. a Cloudflare HTML block page): same
 * surface as jsonResponse, but json() rejects the way fetch's would on HTML.
 */
export function htmlResponse (
  status: number,
  { headers = {}, body = "<html></html>" }: { headers?: Record<string, string>, body?: string } = {},
): any {
  const response = jsonResponse(body, { status, headers });
  response.json = async () => { throw new SyntaxError("Unexpected token '<'"); };
  return response;
}
