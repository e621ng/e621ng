import Hotkeys from "@/core/hotkeys";

export type NavDirection = "prev" | "next";

// Ordered: the first container holding a matching link wins.
const SOURCES = [
  ".search-seq-nav",
  ".paginator",
  ".pool-nav li.pool-selected-true, .set-nav li.set-selected-true",
];

/** Previous / next post navigation on posts#show: search sequence, pool and set links. */
export default class Navigation {

  static href (direction: NavDirection): string | undefined {
    for (const source of SOURCES) {
      const href = $(source).find(`a[rel~=${direction}]`).first().attr("href");
      if (href) return href;
    }
    return undefined;
  }

  static prevHref (): string | undefined { return Navigation.href("prev"); }

  static nextHref (): string | undefined { return Navigation.href("next"); }

  static hasPrev (): boolean { return Boolean(Navigation.prevHref()); }

  static hasNext (): boolean { return Boolean(Navigation.nextHref()); }

  static prev (): void {
    const href = Navigation.prevHref();
    if (href) Navigation.navigate(href);
  }

  static next (): void {
    const href = Navigation.nextHref();
    if (href) Navigation.navigate(href);
  }

  static registerHotkeys (): void {
    Hotkeys.register("prev", () => Navigation.prev());
    Hotkeys.register("next", () => Navigation.next());
  }

  private static navigate (href: string): void {
    location.href = href;
  }
}
