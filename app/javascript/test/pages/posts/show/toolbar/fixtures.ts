import { vi } from "vitest";

export interface ToolbarPageOptions {
  score?: number;
  up?: number;
  down?: number;
  favorited?: boolean;
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
 * the image container, the score in the sidebar, and the toolbar markup from `_toolbar.html.erb`.
 */
export function renderToolbarPage ({
  score = 0,
  up = 0,
  down = 0,
  favorited = false,
  notesEnabled = false,
}: ToolbarPageOptions = {}): void {
  const state = score > 0 ? 1 : (score < 0 ? -1 : 0);
  const scoreClass = score > 0 ? "score-positive" : (score < 0 ? "score-negative" : "score-neutral");

  document.body.innerHTML = `
    <section id="image-container" data-id="${POST_ID}" data-is-favorited="${favorited}">
      <div id="note-container" enabled="${notesEnabled}"></div>
    </section>
    <span class="post-score ${scoreClass}">${score}</span>

    <section id="ptbr-wrapper">
      <div class="ptbr-vote" data-score="${score}" data-up="${up}" data-down="${down}" data-state="${state}" data-vote="0">
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
  PostsShowToolbar.init();
  return PostsShowToolbar;
}

/** Lets pending promise callbacks run. */
export async function flush (): Promise<void> {
  for (let i = 0; i < 5; i++) await Promise.resolve();
}
