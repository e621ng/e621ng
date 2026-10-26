import HTTP from "@/utility/HTTP";
import State from "@/utility/StateUtils";
import Toast from "@/utility/Toast";

type SubscribeResponse = {
  added: { id: number; tag_name: string }[];
  skipped: { name: string; reason: string }[];
};

/**
 * Toggles the wiki page's tag subscription in place. Without JS, the link falls back to
 * rails-ujs and a full-page round trip.
 */
export default class SubscribeTag {

  public static bootstrap (): void {
    const link = document.getElementById("tag-subscription-toggle") as HTMLAnchorElement | null;
    if (!link) return;

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

  private static async subscribe (link: HTMLAnchorElement): Promise<void> {
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

  private static async unsubscribe (link: HTMLAnchorElement): Promise<void> {
    const response = await HTTP.request(`${link.pathname}.json`, { method: "DELETE" }).catch(() => null);
    // A 404 means it was already gone, which is the state the user asked for
    if (!response || (!response.ok && response.status !== 404)) {
      Toast.alert("Failed to unsubscribe from this tag.");
      return;
    }
    const params = new URLSearchParams({ tag_name: link.dataset.tag ?? "" });
    this.render(link, false, `/tag_subscriptions?${params}`);
  }

  private static render (link: HTMLAnchorElement, subscribed: boolean, href: string): void {
    link.dataset.subscribed = String(subscribed);
    link.dataset.method = subscribed ? "delete" : "post";
    link.href = href;
    link.textContent = subscribed ? "Unsubscribe" : "Subscribe";
    link.classList.toggle("btn-neutral", subscribed);
    link.classList.toggle("btn-success", !subscribed);
    link.title = subscribed
      ? "Stop counting new posts with this tag in your subscriptions"
      : "Count new posts with this tag in your subscriptions";
  }
}

State.onReady(() => SubscribeTag.bootstrap());
