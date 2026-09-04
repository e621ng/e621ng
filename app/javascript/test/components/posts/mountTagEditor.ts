import { flushPromises, mount, VueWrapper } from "@vue/test-utils";
import { vi } from "vitest";
import { nextTick } from "vue";
import { jsonResponse, setSiteData } from "../../helpers";

// IMPORTANT: `vi.mock` is file-scoped and hoisted, so it cannot live in this helper.
// Every test file that mounts the tag editor must include this header block itself,
// BEFORE any imports:
//
//   vi.mock("@/pages/posts/posts", () => ({ default: { update_tag_count: vi.fn() } }));
//   vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
//   vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));
//
// posts.js MUST be mocked — the real module drags in Hotkeys/PostVote side effects.
// Toast is in the tree via tag_preview.vue. No DTextFormatter here.
//
// Transport: everything is on fetch (via the HTTP helper). Related-tag lookups
// are captured as controllable per-call records that tests settle manually —
// which is what makes the loading states and the in-flight guard pinnable.
// All other fetches (tag_preview) auto-resolve inert.

export interface RelatedTagRecord {
  name: string;
  category_id: number;
}

export interface MountTagEditorOptions {
  // Root props, normally provided by the RelatedTag.ts bootstrap.
  // postTags = the initial textarea value; the server ships
  // categorized_tag_list_text + " " (newline-grouped, trailing space).
  postTags?: string;
  uploadTags?: RelatedTagRecord[];
  recentTags?: RelatedTagRecord[];
  // CurrentUser.settings.autocomplete — gates the autocomplete init in mounted()
  autocomplete?: boolean;
}

/** One captured related-tags fetch, settled manually by the test. */
export interface RelatedCall {
  url: string;
  /** The request method (the lookup POSTs — huge tag strings exceed URL limits). */
  method: string;
  /** The parsed form-urlencoded request body. */
  params: URLSearchParams;
  /** Settle the request successfully with a JSON body. */
  resolve: (data: unknown) => Promise<void>;
  /** Settle the request as a failure (500 — the helper rejects on non-2xx). */
  fail: () => Promise<void>;
}

export interface MountedTagEditor {
  wrapper: VueWrapper;
  /** Every /related_tag/ fetch made so far, in order. */
  fetchCalls: RelatedCall[];
  /** The mocked Post.update_tag_count (same instance the component calls). */
  updateTagCount: ReturnType<typeof vi.fn>;
  /** The mocked Autocomplete.initialize_autocomplete. */
  initializeAutocomplete: ReturnType<typeof vi.fn>;
  restore: () => void;
}

const wrappers: VueWrapper[] = [];
/** Call in each test file's afterEach to tear down mounted editors. */
export function unmountAll (): void {
  for (const wrapper of wrappers.splice(0)) wrapper.unmount();
}

export async function mountTagEditor (opts: MountTagEditorOptions = {}): Promise<MountedTagEditor> {
  // Seed the singleton blob BEFORE importing the component (singletons memoize at
  // first import; setup.ts's vi.resetModules() gives a fresh read each test).
  // NOTE: settings default to false in CurrentUser's parse, so autocomplete must
  // be seeded explicitly.
  setSiteData("site-user", {
    id: 1,
    name: "tester",
    level: 20,
    level_string: "Member",
    is: { member: true },
    can: {},
    settings: { autocomplete: opts.autocomplete ?? true },
  });

  // Disable the tag-preview auto-fetch so its 1s debounce can't fire after the
  // component unmounts. (LStorage serializes booleans as JSON.)
  window.localStorage.setItem("e6.posts.tagpreview", "false");

  // Controllable fetch seam. Related-tag lookups become manually-settled
  // deferreds (so tests can observe in-flight state and settle in any order);
  // everything else (tag_preview) auto-resolves inert.
  const fetchCalls: RelatedCall[] = [];
  vi.spyOn(globalThis, "fetch").mockImplementation(((url: string, init?: RequestInit) => {
    if (!String(url).includes("/related_tag/"))
      return Promise.resolve(jsonResponse([]) as Response);
    return new Promise((settle) => {
      fetchCalls.push({
        url: String(url),
        method: init?.method ?? "GET",
        params: new URLSearchParams(String(init?.body ?? "")),
        resolve: async (data: unknown) => {
          settle(jsonResponse(data));
          await flushPromises();
          await nextTick();
        },
        fail: async () => {
          settle(jsonResponse({}, { status: 500 }));
          await flushPromises();
          await nextTick();
        },
      });
    });
  }) as any);

  // Reset the module cache so CurrentUser re-reads the freshly-seeded blob —
  // even on a second mount within one test.
  vi.resetModules();

  // vi.mock factory results are memoized across resetModules, so the mocked fns
  // are shared by every mount in a test file and accumulate calls. Grab them
  // before mounting and clear, so each mount records only its own calls.
  const updateTagCount = (await import("@/pages/posts/posts")).default.update_tag_count;
  const initializeAutocomplete = (await import("@/components/autocomplete")).default.initialize_autocomplete;
  updateTagCount.mockClear();
  initializeAutocomplete.mockClear();

  const TagEditor = (await import("@/pages/posts/show/tag_editor.vue")).default;
  const wrapper = mount(TagEditor, {
    attachTo: document.body,
    props: {
      postTags: opts.postTags ?? "wolf canine\nforest tree ",
      uploadTags: opts.uploadTags ?? [],
      recentTags: opts.recentTags ?? [],
    },
  });
  wrappers.push(wrapper);

  // Settle the 20ms focus/auto-height timer from mounted() while the component
  // is still mounted — otherwise it fires after an early unmount and its
  // $refs.otherTags dereference throws into the unhandled-error channel. Doing
  // it here also makes focus assertable immediately.
  await new Promise((r) => setTimeout(r, 25));

  const restore = () => {
    wrapper.unmount();
  };

  return { wrapper, fetchCalls, updateTagCount, initializeAutocomplete, restore };
}
