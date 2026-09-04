interface HTTPOptions {
  method?: string;
  params?: Record<string, string | number | undefined | null>;
  body?: FormData | URLSearchParams | string;
  headers?: Record<string, string>;
}

/**
 * Thin fetch wrapper: query-string serialization, CSRF on non-GET requests, and
 * `credentials: "include"`. Returns the raw Response so callers keep full control
 * over status/header/body handling (jQuery.ajax used to add CSRF via @rails/ujs;
 * fetch does not, so this is where the token is attached).
 */
export default class HTTP {
  static request (url: string, opts: HTTPOptions = {}): Promise<Response> {
    const method = (opts.method ?? "GET").toUpperCase();
    const headers: Record<string, string> = { ...(opts.headers ?? {}) };
    if (method !== "GET" && method !== "HEAD")
      headers["X-CSRF-Token"] = HTTP.csrfToken();

    return fetch(HTTP.withParams(url, opts.params), {
      method,
      headers,
      credentials: "include",
      body: opts.body,
    });
  }

  static get (url: string, params?: HTTPOptions["params"]): Promise<Response> {
    return HTTP.request(url, { method: "GET", params });
  }

  static async getJSON<T = any> (url: string, params?: HTTPOptions["params"]): Promise<T> {
    return (await HTTP.get(url, params)).json();
  }

  static post (url: string, body?: HTTPOptions["body"], opts: HTTPOptions = {}): Promise<Response> {
    return HTTP.request(url, { ...opts, method: "POST", body });
  }

  static async postJSON<T = any> (url: string, body?: HTTPOptions["body"], opts: HTTPOptions = {}): Promise<T> {
    return (await HTTP.post(url, body, opts)).json();
  }

  private static csrfToken (): string {
    return document.querySelector('meta[name="csrf-token"]')?.getAttribute("content") ?? "";
  }

  private static withParams (url: string, params?: HTTPOptions["params"]): string {
    if (!params) return url;
    const search = new URLSearchParams();
    for (const [key, value] of Object.entries(params))
      if (value !== undefined && value !== null) search.append(key, String(value));
    const query = search.toString();
    return query ? `${url}?${query}` : url;
  }
}
