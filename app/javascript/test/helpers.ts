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
