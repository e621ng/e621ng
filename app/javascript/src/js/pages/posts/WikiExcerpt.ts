import LStorage from "@/utility/storage/Local";

const CLOSED = 0, OPEN = 1, DISMISSED = 2;

/** The collapsible wiki excerpt above the posts index / favorites gallery. State persists in local storage. */
export default class WikiExcerpt {

  static initialize (): void {
    for (const section of document.querySelectorAll<HTMLElement>(".wiki-excerpt"))
      WikiExcerpt.bind(section);
  }

  private static bind (section: HTMLElement): void {
    const state = LStorage.Posts.WikiExcerpt;
    if (state === DISMISSED) return;

    let open = state === OPEN;
    section.classList.toggle("open", open);
    section.classList.remove("hidden");

    // Skip the rollout animation on first load
    window.setTimeout(() => section.classList.remove("loading"), 250);

    section.querySelector("h3.wiki-excerpt-toggle")?.addEventListener("click", (event) => {
      event.preventDefault();
      open = !open;
      section.classList.toggle("open", open);
      LStorage.Posts.WikiExcerpt = open ? OPEN : CLOSED;
    });

    // The button sits inside the toggle header
    section.querySelector("button.wiki-excerpt-dismiss")?.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      section.classList.add("hidden");
      LStorage.Posts.WikiExcerpt = DISMISSED;
    });
  }
}
