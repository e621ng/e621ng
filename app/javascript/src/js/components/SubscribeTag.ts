import HTTP from "@/utility/HTTP";
import Toast from "@/utility/Toast";

type SubscribeResponse = {
  added: { id: number; tag_name: string }[];
  skipped: { name: string; reason: string }[];
};

/**
 * Toggles tag subscription buttons in place. Without JS, the links fall back to rails-ujs
 * and a full-page round trip.
 */
export default class SubscribeTag {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: SubscribeTag | null = null;
  public static get instance (): SubscribeTag {
    if (!SubscribeTag._instance)
      SubscribeTag._instance = new SubscribeTag();
    return SubscribeTag._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private constructor () {
    if (SubscribeTag._instance)
      throw new Error("SubscribeTag is a singleton class. Use SubscribeTag.instance to access the instance.");

    for (const link of document.querySelectorAll<HTMLAnchorElement>("a.tag-subscription-toggle"))
      link.addEventListener("click", (event) => {
        event.preventDefault();
        // Keeps rails-ujs's delegated data-method handler from also submitting
        event.stopImmediatePropagation();
        if (link.dataset.busy === "true") return;
        link.dataset.busy = "true";
        const action = link.dataset.subscribed === "true" ? this.unsubscribe(link) : this.subscribe(link);
        action.finally(() => { delete link.dataset.busy; });
      });
  }

  private async subscribe (link: HTMLAnchorElement): Promise<void> {
    const body = new URLSearchParams({ tag_name: link.dataset.tag ?? "" });
    let result: SubscribeResponse;
    try {
      result = await HTTP.postJSON<SubscribeResponse>("/tag_subscriptions.json", body);
    } catch {
      Toast.alert("Failed to subscribe to this tag.");
      return;
    }

    const added = result.added[0];
    if (!added) {
      Toast.alert(`Not subscribed: ${result.skipped[0]?.reason ?? "unknown error"}.`);
      return;
    }
    this.render(link, true, `/tag_subscriptions/${added.id}`);
  }

  private async unsubscribe (link: HTMLAnchorElement): Promise<void> {
    const response = await HTTP.request(`${link.pathname}.json`, { method: "DELETE" }).catch(() => null);
    // A 404 means it was already gone, which is the state the user asked for
    if (!response || (!response.ok && response.status !== 404)) {
      Toast.alert("Failed to unsubscribe from this tag.");
      return;
    }
    const params = new URLSearchParams({ tag_name: link.dataset.tag ?? "" });
    this.render(link, false, `/tag_subscriptions?${params}`);
  }

  private render (link: HTMLAnchorElement, subscribed: boolean, href: string): void {
    link.dataset.subscribed = String(subscribed);
    link.dataset.method = subscribed ? "delete" : "post";
    link.href = href;
    link.textContent = subscribed ? "Unsubscribe" : "Subscribe";
    link.classList.toggle("btn-neutral", subscribed);
    link.classList.toggle("btn-success", !subscribed);
    link.title = subscribed
      ? "Stop counting new posts with this tag in your subscriptions"
      : "Count new posts with this tag in your subscriptions";

    // The server's count is cached, so it is adjusted locally rather than refetched
    const counter = document.querySelector<HTMLElement>(`.tag-subscriber-count[data-tag="${CSS.escape(link.dataset.tag ?? "")}"]`);
    if (!counter) return;
    const count = Math.max(0, (Number(counter.dataset.count) || 0) + (subscribed ? 1 : -1));
    const noun = count === 1 ? "subscriber" : "subscribers";
    counter.dataset.count = String(count);
    counter.textContent = `${SubscribeTag.countLabel(count)} ${noun}`;
    counter.title = `${count.toLocaleString("en-US")} ${noun}`;
  }

  // Mirrors TagSetPresenter.post_count_label
  private static countLabel (count: number): string {
    if (count < 1_000) return String(count);
    if (count < 10_000) return (count / 1_000).toFixed(1) + "k";
    if (count < 1_000_000) return Math.floor(count / 1_000) + "k";
    if (count < 10_000_000) return (count / 1_000_000).toFixed(1) + "m";
    return Math.floor(count / 1_000_000) + "m";
  }
}
