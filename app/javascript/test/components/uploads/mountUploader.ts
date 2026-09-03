import { mount, VueWrapper } from "@vue/test-utils";
import { vi } from "vitest";
import $ from "jquery";
import { setSiteData } from "../../helpers";

// IMPORTANT: `vi.mock` is file-scoped and hoisted, so it cannot live in this helper.
// Every test file that mounts the uploader must include this header block itself,
// BEFORE any imports:
//
//   vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
//   vi.mock("@/components/DTextFormatter.ts", () => ({ default: vi.fn() }));
//   vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));
//
// The helper only performs the runtime setup (blob seeding, URL, network spies,
// navigation stub) and the fresh dynamic import + mount.

export interface UploadTag {
  name: string;
  count: number;
  category_id: number;
}

export interface MountUploaderOptions {
  // CurrentUser (#site-user) permission flags
  admin?: boolean; // → allowLockedTags
  privileged?: boolean; // → allowRatingLock
  uploadFree?: boolean; // → allowUploadAsPending
  // UploadData (#upload-data)
  compactMode?: boolean; // normalMode = !compactMode
  safeSite?: boolean; // hides the e/q rating buttons
  uploadTags?: UploadTag[];
  recentTags?: UploadTag[];
  verifiedArtistTags?: string[];
  // Settings.Posts (#site-settings) — consumed by file_input
  maxFileSize?: number;
  maxFileSizes?: Record<string, number>;
  // mounted() reads window.location.search for its query-param import
  search?: string;
}

export interface MountedUploader {
  wrapper: VueWrapper;
  ajax: ReturnType<typeof vi.spyOn>;
  getJSON: ReturnType<typeof vi.spyOn>;
  fetchSpy: ReturnType<typeof vi.spyOn>;
  locationAssign: ReturnType<typeof vi.fn>;
  restore: () => void;
}

const wrappers: VueWrapper[] = [];
/** Call in each test file's afterEach to tear down mounted uploaders. */
export function unmountAll (): void {
  for (const wrapper of wrappers.splice(0)) wrapper.unmount();
}

// jqXHR-ish chainable so `$.getJSON(...).always(cb)` and friends don't throw
// when the spy is left inert (individual tests override to drive callbacks).
function chainable (): any {
  const stub: any = {
    done: () => stub,
    fail: () => stub,
    always: (cb?: () => void) => {
      cb?.();
      return stub;
    },
  };
  return stub;
}

export async function mountUploader (opts: MountUploaderOptions = {}): Promise<MountedUploader> {
  // 1. Seed the singleton blobs BEFORE importing the component (singletons memoize
  //    at first import; setup.ts's vi.resetModules() gives a fresh read each test).
  setSiteData("site-user", {
    id: 1,
    name: "tester",
    level: 20,
    level_string: "Member",
    is: { member: true, admin: !!opts.admin, privileged: !!opts.privileged },
    can: { upload_free: !!opts.uploadFree, approve_posts: false },
  });
  setSiteData("upload-data", {
    safe_site: !!opts.safeSite,
    compact_mode: !!opts.compactMode,
    verified_artist_tags: opts.verifiedArtistTags ?? [],
    upload_tags: opts.uploadTags ?? [],
    recent_tags: opts.recentTags ?? [],
  });
  setSiteData("site-settings", {
    Posts: {
      max_file_size: opts.maxFileSize ?? 1048576,
      max_file_sizes: opts.maxFileSizes ?? {},
    },
  });

  // Disable the tag-preview auto-fetch so its 1s debounce can't fire a stray
  // $.ajax after the component unmounts. (LStorage serializes booleans as JSON.)
  window.localStorage.setItem("e6.posts.tagpreview", "false");

  // 2. + 4. Replace window.location wholesale with a URL-based stand-in. This
  //    controls the query string mounted() reads AND stubs .assign (jsdom's real
  //    location.assign is non-configurable and throws "Not implemented: navigation").
  const originalLocation = window.location;
  const locationAssign = vi.fn();
  const fakeLocation: any = new URL("http://localhost/uploads/new" + (opts.search ?? ""));
  fakeLocation.assign = locationAssign;
  Object.defineProperty(window, "location", { configurable: true, writable: true, value: fakeLocation });

  // 3. Inert-by-default network spies. jQuery === $ (same singleton the app calls).
  const ajax = vi.spyOn($, "ajax").mockReturnValue(chainable());
  const getJSON = vi.spyOn($, "getJSON").mockReturnValue(chainable());
  const fetchSpy = vi
    .spyOn(globalThis, "fetch")
    .mockResolvedValue({ ok: true, status: 200, json: async () => ([]) } as unknown as Response);

  // 5. Reset the module cache so the singletons (CurrentUser/UploadData/Settings)
  //    re-read the freshly-seeded blobs — even on a second mount within one test.
  //    (The $/fetch spies are on stable globals and survive the reset.)
  vi.resetModules();
  const Uploader = (await import("@/pages/uploads/new/uploader.vue")).default;
  const wrapper = mount(Uploader, { attachTo: document.body });
  wrappers.push(wrapper);

  const restore = () => {
    wrapper.unmount();
    Object.defineProperty(window, "location", { configurable: true, writable: true, value: originalLocation });
  };

  return { wrapper, ajax, getJSON, fetchSpy, locationAssign, restore };
}
