import HTTP, { HTTPOptions } from "@/utility/HTTP";
import TaskQueue, { TaskCancelled } from "@/utility/TaskQueue";

/** A non-2xx response. `message` is the backend's error text (see HTTP.errorMessage). */
export class ApiError extends Error {
  public status: number;

  constructor (status: number, message: string) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

export interface ApiQueueOptions {
  name: string;
  unique?: boolean;
  delay?: number;
  priority?: boolean;
}

export interface ApiRequestOptions extends Omit<HTTPOptions, "body"> {
  /** Serialized as the JSON body, with Content-Type: application/json. */
  json?: unknown;
  /** When set, the request is scheduled through TaskQueue.add with these options. */
  queue?: ApiQueueOptions;
  /** Toast text for a non-2xx response. Default: "Error: " + error.message. */
  errorText?: (error: ApiError) => string;
}

/**
 * Model-layer request policy shared by the API wrappers: optional TaskQueue
 * scheduling, JSON bodies, and failure reporting through `danbooru:error`.
 * Every failure is both reported and rejected, so callers only handle success.
 */
export default class ApiRequest {

  /** Sends the request and resolves with the ok Response. */
  static send (url: string, opts: ApiRequestOptions = {}): Promise<Response> {
    const { json, queue, errorText, headers, ...rest } = opts;

    const run = () => HTTP.request(url, {
      ...rest,
      headers: {
        ...(json !== undefined ? { "Content-Type": "application/json" } : {}),
        ...(headers ?? {}),
      },
      body: json !== undefined ? JSON.stringify(json) : undefined,
    });

    const pending = queue ? TaskQueue.add(run, queue) : run();
    return pending.then(async (response) => {
      if (response.ok) return response;

      const error = new ApiError(response.status, await HTTP.errorMessage(response));
      $(window).trigger("danbooru:error", errorText ? errorText(error) : "Error: " + error.message);
      throw error;
    }, (error) => {
      if (error instanceof TaskCancelled) return Promise.reject(error);
      console.error(error);
      $(window).trigger("danbooru:error", "Error: " + error.message);
      throw error;
    });
  }

  /** send() plus JSON parsing. Only for endpoints that always return a body. */
  static json<T = any> (url: string, opts: ApiRequestOptions = {}): Promise<T> {
    return ApiRequest.send(url, opts).then((response) => response.json().then(undefined, (error) => {
      console.error("Failed to parse response as JSON:", error);
      $(window).trigger("danbooru:error", "Error: " + error.message);
      throw error;
    }));
  }
}
