import { vi } from "vitest";

export interface ToolbarPageOptions {
  score?: number;
  up?: number;
  down?: number;
  vote?: number;
  favorited?: boolean;
  favCount?: number;
  notesEnabled?: boolean;
}

export const POST_ID = 123;

/** Hotkey listeners captured by the `@/core/hotkeys` mock. Specs call `vi.mock` themselves. */
export const hotkeys = new Map<string, () => void>();

export function pressHotkey (name: string): void {
  const listener = hotkeys.get(name);
  if (!listener) throw new Error(`No hotkey registered for "${name}"`);
  listener();
}

/**
 * Renders the parts of posts#show that the toolbar touches:
 * the embedded post payload, the image container, the score in the sidebar,
 * and the toolbar markup from `_toolbar.html.erb`.
 */
export function renderToolbarPage ({
  score = 0,
  up = 0,
  down = 0,
  vote = 0,
  favorited = false,
  favCount = 0,
  notesEnabled = false,
}: ToolbarPageOptions = {}): void {
  const state = score > 0 ? 1 : (score < 0 ? -1 : 0);
  const scoreClass = score > 0 ? "score-positive" : (score < 0 ? "score-negative" : "score-neutral");

  // Same shape as `post_show_base64` (PostBlueprint); only the fields the toolbar reads
  const postData = btoa(JSON.stringify({
    id: POST_ID,
    stats: { score: { up, down, total: score }, fav_count: favCount, is_favorited: favorited, vote },
  }));

  document.body.innerHTML = `
    <script type="text/plain" id="post-data" data-encoding="base64">${postData}</script>
    <section id="image-container" data-id="${POST_ID}" data-is-favorited="${favorited}">
      <div id="note-container" enabled="${notesEnabled}"></div>
    </section>
    <span class="post-score ${scoreClass}">${score}</span>

    <section id="ptbr-wrapper">
      <div class="ptbr-vote" data-score="${score}" data-up="${up}" data-down="${down}" data-state="${state}" data-vote="${vote}">
        <button class="ptbr-vote-button" data-action="1" processing="false">Up</button>
        <button class="ptbr-score">${score}</button>
        <span class="ptbr-breakdown hidden"><span>${up}</span><span>${down}</span></span>
        <button class="ptbr-vote-button" data-action="-1" processing="false">Down</button>
      </div>
      <div class="ptbr-favorite">
        <button class="ptbr-favorite-button anim" favorited="${favorited}" processing="false">Fav</button>
      </div>
      <div class="ptbr-notes">
        <button class="ptbr-notes-button" enabled="true" aria-pressed="false">Notes</button>
      </div>
      <div class="ptbr-etc">
        <button class="ptbr-etc-toggle" aria-expanded="false" aria-controls="ptbr-etc-menu">More</button>
        <div class="ptbr-etc-menu hidden" id="ptbr-etc-menu" role="menu">
          <a href="/download" class="ptbr-etc-download">Download</a>
          <button class="ptbr-share-button">Share</button>
          <button class="ptbr-etc-pool">Add to Pool</button>
          <button class="ptbr-etc-set">Add to Set</button>
        </div>
      </div>
    </section>

    <section id="ptbr-share-menu" class="hidden">
      <input type="text" class="ptbr-share-link" readonly value="https://e621.net/posts/${POST_ID}" />
      <button class="ptbr-share-copy" data-value="https://e621.net/posts/${POST_ID}">Copy</button>
    </section>
  `;
}

/** Imports the toolbar fresh and initializes it against the rendered page. */
export async function loadToolbar () {
  vi.resetModules();
  hotkeys.clear();
  const PostsShowToolbar = (await import("@/pages/posts/show/toolbar")).default;
  void PostsShowToolbar.instance;
  return PostsShowToolbar;
}

/** The CurrentPost instance the loaded toolbar is bound to. Call after `loadToolbar`. */
export async function currentPost () {
  return (await import("@/models/CurrentPost")).default;
}

/** The TaskCancelled class from the same module registry as the loaded toolbar. */
export async function taskCancelled () {
  return (await import("@/utility/TaskQueue")).TaskCancelled;
}

/** Lets pending promise callbacks run. */
export async function flush (): Promise<void> {
  for (let i = 0; i < 5; i++) await Promise.resolve();
}
