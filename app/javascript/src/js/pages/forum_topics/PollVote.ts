import DeferredPostLoader from "@/core/DeferredPostLoader";
import HTTP from "@/utility/HTTP";
import ToastManager from "@/utility/Toast";

interface BallotResponse {
  option_ids: number[];
  html: string;
  posts: Record<number, any>;
}

/**
 * Submits the poll ballot in place. Without JS the forms fall back to a normal
 * PUT/DELETE round trip. Events are delegated on the stable container because
 * every successful submit swaps the whole poll section.
 */
export default class PollVote {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: PollVote | null = null;
  public static get instance (): PollVote {
    if (!PollVote._instance)
      PollVote._instance = new PollVote();
    return PollVote._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private container: HTMLElement | null;

  private constructor () {
    if (PollVote._instance)
      throw new Error("PollVote is a singleton class. Use PollVote.instance to access the instance.");

    this.container = document.querySelector<HTMLElement>("#forum-poll-container");
    if (!this.container) return;

    this.container.addEventListener("submit", (event) => {
      const form = event.target as HTMLFormElement;
      if (form.matches("form.forum-poll-ballot"))
        this.handle(event, form, "PUT");
      else if (form.matches("form.forum-poll-clear-form"))
        this.handle(event, form, "DELETE");
    });

    this.container.addEventListener("change", (event) => {
      const input = event.target as HTMLInputElement;
      if (input.matches("form.forum-poll-ballot input[type='checkbox']"))
        this.enforceMaxChoices(input.form);
    });
    this.enforceMaxChoices(this.section?.querySelector<HTMLFormElement>("form.forum-poll-ballot") ?? null);
  }

  private get section (): HTMLElement | null {
    return this.container?.querySelector<HTMLElement>("#forum-poll") ?? null;
  }

  private get state (): string {
    return this.section?.dataset.state ?? "ready";
  }

  private set state (value: string) {
    const section = this.section;
    if (section) section.dataset.state = value;
  }


  /* ============================== */
  /* ========== Handling ========== */
  /* ============================== */

  private handle (event: Event, form: HTMLFormElement, method: "PUT" | "DELETE"): void {
    event.preventDefault();
    // Keep rails-ujs from also submitting the form
    event.stopImmediatePropagation();
    if (this.state !== "ready") return;

    const body = new FormData(form);
    body.delete("_method");
    body.delete("authenticity_token");
    if (method === "PUT" && !body.has("option_ids[]")) {
      ToastManager.alert("Select at least one option.");
      return;
    }

    this.state = "loading";
    void this.submit(form.action, method, body).finally(() => { this.state = "ready"; });
  }

  private async submit (action: string, method: "PUT" | "DELETE", body: FormData): Promise<void> {
    let response: Response;
    try {
      response = await HTTP.request(PollVote.jsonURL(action), { method, body, headers: { Accept: "application/json" } });
    } catch {
      ToastManager.alert("Failed to submit your vote.");
      return;
    }

    if (!response.ok) {
      ToastManager.alert(await HTTP.errorMessage(response, "Failed to submit your vote."));
      return;
    }

    const data: BallotResponse = await response.json();
    this.render(data);
    ToastManager.notice(method === "DELETE" ? "Vote cleared" : "Vote saved");
  }

  private render (data: BallotResponse): void {
    const section = this.section;
    if (!section) return;
    // The staff ballot table ships collapsed; keep it open if the moderator had it open
    const ballotsOpen = section.querySelector<HTMLDetailsElement>("details.forum-poll-ballots")?.open ?? false;
    section.outerHTML = data.html;
    if (ballotsOpen) {
      const ballots = this.section?.querySelector<HTMLDetailsElement>("details.forum-poll-ballots");
      if (ballots) ballots.open = true;
    }
    DeferredPostLoader.loadPostData(data.posts ?? {});
    DeferredPostLoader.renderDTextThumbnails();
    this.enforceMaxChoices(this.section?.querySelector<HTMLFormElement>("form.forum-poll-ballot") ?? null);
  }

  /** Greys out unchecked boxes once the pick-up-to-N cap is reached. */
  private enforceMaxChoices (form: HTMLFormElement | null): void {
    if (!form) return;
    const max = parseInt(this.section?.dataset.maxChoices ?? "1", 10);
    const boxes = Array.from(form.querySelectorAll<HTMLInputElement>("input[type='checkbox']"));
    if (!boxes.length) return;
    const checked = boxes.filter((box) => box.checked).length;
    for (const box of boxes)
      box.disabled = !box.checked && checked >= max;
  }

  private static jsonURL (action: string): string {
    const url = new URL(action, window.location.origin);
    if (!url.pathname.endsWith(".json")) url.pathname += ".json";
    return url.pathname + url.search;
  }
}
