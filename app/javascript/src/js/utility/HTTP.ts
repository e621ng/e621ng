interface HTTPOptions {
  method?: string;
  params?: Record<string, string | number | undefined | null>;
  body?: FormData | URLSearchParams | string;
  headers?: Record<string, string>;
}

/**
 * Thin fetch wrapper: query-string serialization, CSRF on non-GET requests, and
 * same-origin credentials. Returns the raw Response so callers keep full control
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
      credentials: "same-origin", // Match jQuery XHR (withCredentials:false)
      body: opts.body,
    });
  }

  static get (url: string, params?: HTTPOptions["params"]): Promise<Response> {
    return HTTP.request(url, { method: "GET", params });
  }

  static async getJSON<T = any> (url: string, params?: HTTPOptions["params"]): Promise<T> {
    return HTTP.json(await HTTP.get(url, params));
  }

  static post (url: string, body?: HTTPOptions["body"], opts: HTTPOptions = {}): Promise<Response> {
    return HTTP.request(url, { ...opts, method: "POST", body });
  }

  static async postJSON<T = any> (url: string, body?: HTTPOptions["body"], opts: HTTPOptions = {}): Promise<T> {
    return HTTP.json(await HTTP.post(url, body, opts));
  }

  // The JSON sugar only resolves on 2xx (an error body could still be valid JSON,
  // which callers must not mistake for success); use `request`/`get`/`post` for
  // non-ok handling.
  private static json<T> (response: Response): Promise<T> {
    if (!response.ok) throw new Error(`Request failed: ${response.status}`);
    return response.json();
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
