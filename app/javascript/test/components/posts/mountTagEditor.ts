import { mount, VueWrapper } from "@vue/test-utils";
import { vi } from "vitest";
import { nextTick } from "vue";
import { setSiteData } from "../../helpers";

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
// The transport seam differs from the other mount helpers: findRelated posts via
// $.ajax (not fetch), so the harness spies on jQuery and returns controllable
// per-call records that tests settle manually — and out of order, which is what
// makes the loading states and the B3 race pinnable. An inert fetch spy still
// covers tag_preview's HTTP path.

export interface RelatedTagRecord {
  name: string;
  category_id: number;
}

export interface MountTagEditorOptions {
  // window.uploaderSettings.postTags — the initial textarea value. The server
  // ships categorized_tag_list_text + " " (newline-grouped, trailing space).
  postTags?: string;
  // window.uploaderSettings side-channel consumed by related.vue's fallback
  uploadTags?: RelatedTagRecord[];
  recentTags?: RelatedTagRecord[];
  // CurrentUser.settings.autocomplete — gates the autocomplete init in mounted()
  autocomplete?: boolean;
}

/** One captured $.ajax invocation, settled manually by the test. */
export interface AjaxCall {
  url: string;
  opts: Record<string, any>;
  /** Fire the success callback with `data`, then the always-callbacks. */
  resolve: (data: unknown) => Promise<void>;
  /** Fire only the always-callbacks (a failed request — no success). */
  fail: () => Promise<void>;
}

export interface MountedTagEditor {
  wrapper: VueWrapper;
  /** Every $.ajax call made so far, in order. */
  ajaxCalls: AjaxCall[];
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
  delete (window as any).uploaderSettings;
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

  // The inline-script global posts/show.html.erb emits (postTags) plus the two
  // arrays RelatedTag.ts stuffs in for related.vue's fallback. This is the exact
  // surface the G1 globals cleanup will delete — the pins live on it on purpose.
  (window as any).uploaderSettings = {
    postTags: opts.postTags ?? "wolf canine\nforest tree ",
    uploadTags: opts.uploadTags ?? [],
    recentTags: opts.recentTags ?? [],
  };

  // Disable the tag-preview auto-fetch so its 1s debounce can't fire after the
  // component unmounts. (LStorage serializes booleans as JSON.)
  window.localStorage.setItem("e6.posts.tagpreview", "false");

  // Inert fetch spy for tag_preview's HTTP path (nothing in the editor itself
  // uses fetch — findRelated is still on $.ajax, see below).
  vi.spyOn(globalThis, "fetch")
    .mockResolvedValue({ ok: true, status: 200, headers: { get: () => null }, json: async () => ([]) } as unknown as Response);

  // Controllable $.ajax seam. jqXHR surface is only what the component chains:
  // $.ajax(url, opts).always(fn); success arrives via opts.success.
  const ajaxCalls: AjaxCall[] = [];
  vi.spyOn(globalThis.$ as any, "ajax").mockImplementation(((url: string, opts: Record<string, any>) => {
    const alwaysCbs: Array<() => void> = [];
    ajaxCalls.push({
      url,
      opts,
      resolve: async (data: unknown) => {
        opts.success?.(data);
        for (const cb of alwaysCbs) cb();
        await nextTick();
      },
      fail: async () => {
        for (const cb of alwaysCbs) cb();
        await nextTick();
      },
    });
    const jqxhr = {
      always (fn: () => void) {
        alwaysCbs.push(fn);
        return jqxhr;
      },
    };
    return jqxhr;
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
  const wrapper = mount(TagEditor, { attachTo: document.body });
  wrappers.push(wrapper);

  // Settle the 20ms focus/auto-height timer from mounted() while the component
  // is still mounted — otherwise it fires after an early unmount and its
  // $refs.otherTags dereference throws into the unhandled-error channel. Doing
  // it here also makes focus assertable immediately.
  await new Promise((r) => setTimeout(r, 25));

  const restore = () => {
    wrapper.unmount();
    delete (window as any).uploaderSettings;
  };

  return { wrapper, ajaxCalls, updateTagCount, initializeAutocomplete, restore };
}
