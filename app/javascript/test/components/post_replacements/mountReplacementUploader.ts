import { mount, VueWrapper } from "@vue/test-utils";
import { vi } from "vitest";
import { nextTick } from "vue";
import { setSiteData } from "../../helpers";

// Unlike the uploads mountUploader, no hoisted `vi.mock` header is needed in the
// spec files: this component tree pulls in no Autocomplete, DTextFormatter, or
// Toast. The transport seam is the same as the uploads harness: fetchSpy carries
// submit() (via the HTTP helper) and file-input's whitelist lookup; tests drive
// outcomes with mockResolvedValue(jsonResponse(...)) / mockRejectedValue.

export interface MountReplacementUploaderOptions {
  // CurrentUser (#site-user) → canApprove (renders the as-pending checkbox)
  approver?: boolean;
  // ?post_id= in the page URL; submit() re-reads it from location.search.
  // Defaults to "123"; pass null to omit the parameter entirely.
  postId?: string | null;
  // Additional query parameters (additional_source, reason)
  params?: Record<string, string>;
  // Settings.Posts (#site-settings) — consumed by the embedded file-input
  maxFileSize?: number;
  maxFileSizes?: Record<string, number>;
}

export interface MountedReplacementUploader {
  wrapper: VueWrapper;
  fetchSpy: ReturnType<typeof vi.spyOn>;
  locationAssign: ReturnType<typeof vi.fn>;
  restore: () => void;
}

const wrappers: VueWrapper[] = [];
/** Call in each test file's afterEach to tear down mounted uploaders. */
export function unmountAll (): void {
  for (const wrapper of wrappers.splice(0)) wrapper.unmount();
}

/**
 * Provide an upload value through the observable boundary: the file-input's
 * single `change` emit carrying { value, preview, invalid }.
 */
export async function provideUploadValue (
  wrapper: VueWrapper,
  opts: { value?: string | File, invalid?: boolean } = {},
): Promise<void> {
  const fileInput = wrapper.findComponent(".uploader-file-input") as VueWrapper;
  fileInput.vm.$emit("change", {
    value: opts.value ?? "https://example.com/image.png",
    preview: { url: "", isVideo: false },
    invalid: opts.invalid ?? false,
  });
  await nextTick();
}

export async function mountReplacementUploader (
  opts: MountReplacementUploaderOptions = {},
): Promise<MountedReplacementUploader> {
  // Seed the singleton blobs BEFORE importing the component (singletons memoize
  // at first import; setup.ts's vi.resetModules() gives a fresh read each test).
  setSiteData("site-user", {
    id: 1,
    name: "tester",
    level: 20,
    level_string: "Member",
    is: { member: true },
    can: { upload_free: false, approve_posts: !!opts.approver },
  });
  setSiteData("site-settings", {
    Posts: {
      max_file_size: opts.maxFileSize ?? 1048576,
      max_file_sizes: opts.maxFileSizes ?? {},
    },
  });

  // Replace window.location wholesale with a URL-based stand-in. This controls
  // the query string read at mount (additional_source/reason) AND at submit
  // (post_id), and stubs .assign (jsdom's real location.assign throws).
  const search = new URLSearchParams(opts.params ?? {});
  if (opts.postId !== null) search.set("post_id", opts.postId ?? "123");
  const query = search.toString();
  const originalLocation = window.location;
  const locationAssign = vi.fn();
  const fakeLocation: any = new URL("http://localhost/post_replacements/new" + (query ? `?${query}` : ""));
  fakeLocation.assign = locationAssign;
  Object.defineProperty(window, "location", { configurable: true, writable: true, value: fakeLocation });

  // Inert-by-default transport spy: carries submit() and file-input's whitelist
  // lookup. Tests override / inspect as needed.
  const fetchSpy = vi
    .spyOn(globalThis, "fetch")
    .mockResolvedValue({ ok: true, status: 200, headers: { get: () => null }, json: async () => ({}) } as unknown as Response);

  // Reset the module cache so the singletons (CurrentUser/Settings) re-read the
  // freshly-seeded blobs — even on a second mount within one test.
  vi.resetModules();
  const ReplacementUploader = (await import("@/pages/post_replacements/new/replacement_uploader.vue")).default;
  const wrapper = mount(ReplacementUploader, { attachTo: document.body });
  wrappers.push(wrapper);

  const restore = () => {
    wrapper.unmount();
    Object.defineProperty(window, "location", { configurable: true, writable: true, value: originalLocation });
  };

  return { wrapper, fetchSpy, locationAssign, restore };
}
