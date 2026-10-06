import HTTP from "@/utility/HTTP";
import State from "@/utility/StateUtils";

type BadgeSummary = {
  count: number | null;
  fresh: boolean;
};

/**
 * The navigation badge is rendered from a cached count. When that count was stale, the server
 * kicked off a background refresh; this re-reads the cache a few times so that the badge updates
 * without the user having to navigate to another page.
 */
export default class SavedSearchBadge {

  private static readonly ENDPOINT = "/saved_searches/badge.json";
  private static readonly DELAYS = [2000, 5000, 15000];
  // Matches the cap applied in _navigation.html.erb
  private static readonly MAX_COUNT = 100;

  public static bootstrap (): void {
    const elements = Array.from(document.querySelectorAll<HTMLElement>("[data-notif-count]"));
    if (!elements.some((element) => element.hasAttribute("data-notif-stale"))) return;

    // Background tabs wait until they are looked at, so that opening many at once does not poll from each.
    if (document.hidden)
      document.addEventListener("visibilitychange", () => this.poll(elements), { once: true });
    else this.poll(elements);
  }

  private static poll (elements: HTMLElement[], attempt = 0): void {
    if (attempt >= this.DELAYS.length) return;

    setTimeout(async () => {
      let summary: BadgeSummary;
      try {
        summary = await HTTP.getJSON<BadgeSummary>(this.ENDPOINT);
      } catch {
        return; // Not worth retrying: the next page load picks it up
      }

      if (!summary.fresh) {
        this.poll(elements, attempt + 1);
        return;
      }

      const count = String(Math.min(summary.count ?? 0, this.MAX_COUNT));
      for (const element of elements) {
        element.setAttribute("data-notif-count", count);
        element.removeAttribute("data-notif-stale");
      }
    }, this.DELAYS[attempt]);
  }
}

State.onReady(() => SavedSearchBadge.bootstrap());
