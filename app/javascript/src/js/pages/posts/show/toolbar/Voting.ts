import Hotkeys from "@/core/hotkeys";
import CurrentPost, { PostVoteEvent } from "@/models/CurrentPost";
import Offclick, { OffclickEntry } from "@/utility/Offclick";
import ToastManager from "@/utility/Toast";

/**
 * Vote buttons, score breakdown, and the upvote / downvote hotkeys on the post toolbar.
 * Renders from `CurrentPost.stats`; button state follows the `post:vote:*` events the model emits.
 */
export default class ToolbarVoting {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: ToolbarVoting | null = null;
  public static get instance (): ToolbarVoting {
    if (!ToolbarVoting._instance)
      ToolbarVoting._instance = new ToolbarVoting();
    return ToolbarVoting._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private container: JQuery<HTMLElement>;
  private buttons: JQuery<HTMLElement>;
  private score: JQuery<HTMLElement>;
  private breakdown: JQuery<HTMLElement>;
  private breakdownOffclick: OffclickEntry | null = null;

  /** Whether a vote request is in flight */
  private processing = false;

  private constructor () {
    if (ToolbarVoting._instance)
      throw new Error("ToolbarVoting is a singleton class. Use ToolbarVoting.instance to access the instance.");

    this.container = $(".ptbr-vote").first();
    this.buttons = $("button.ptbr-vote-button");
    this.score = $(".ptbr-score").first();
    this.breakdown = $(".ptbr-breakdown").first();

    this.initBreakdown();
    this.initButtons();
    this.initHotkeys();
    this.initEvents();
  }

  private initBreakdown (): void {
    this.score.on("click", () => {
      // Register the offclick handler on first use
      if (this.breakdownOffclick === null)
        this.breakdownOffclick = Offclick.register(".ptbr-score", ".ptbr-breakdown", () => {
          this.breakdown.addClass("hidden");
        });

      this.breakdownOffclick.disabled = !this.breakdownOffclick.disabled;
      this.breakdown.toggleClass("hidden");
    });
  }

  private initButtons (): void {
    this.buttons.on("click", (event) => {
      if (this.processing) return;
      CurrentPost.vote(Number($(event.currentTarget).data("action")))
        .catch(() => { /* Reported through danbooru:error */ });
    });
  }

  private initHotkeys (): void {
    Hotkeys.register("upvote", () => {
      ToastManager.dismiss("Post upvoted.", "Post downvoted.");
      ToastManager.track(CurrentPost.vote(1), "Updating post...", (data) => {
        // The vote is removed if the user had already upvoted
        switch (data.our_score) {
          case 1: return "Post upvoted.";
          case 0: return "Upvote removed.";
          default: return "This should not happen.";
        }
      });
    });

    Hotkeys.register("downvote", () => {
      ToastManager.dismiss("Post upvoted.", "Post downvoted.");
      ToastManager.track(CurrentPost.vote(-1), "Updating post...", (data) => {
        switch (data.our_score) {
          case -1: return "Post downvoted.";
          case 0: return "Downvote removed.";
          default: return "This should not happen.";
        }
      });
    });
  }

  private initEvents (): void {
    $(document)
      .on("post:vote:start", (_event, data: PostVoteEvent) => {
        this.setProcessing(true);
        this.buttons.filter(`[data-action="${data.direction}"]`).addClass("anim");
      })
      .on("post:vote", () => { this.render(); })
      .on("post:vote:end", () => {
        this.setProcessing(false);
        this.buttons.removeClass("anim");
      });
  }

  // The attribute drives the pressed-state styling
  private setProcessing (value: boolean): void {
    this.processing = value;
    this.buttons.attr("processing", String(value));
  }


  /* ============================== */
  /* ========= Rendering ========== */
  /* ============================== */

  /** Syncs the score displays with `CurrentPost.stats`. */
  public render (): void {
    const { score, vote } = CurrentPost.stats;
    const state = CurrentPost.scoreState;

    // Score in the information section
    $(".post-score").text(score.total)
      .removeClass("score-negative score-neutral score-positive")
      .addClass(state > 0 ? "score-positive" : (state < 0 ? "score-negative" : "score-neutral"));

    // Toolbar vote block
    this.score.text(score.total);
    this.breakdown.html(`<span>${score.up}</span><span>${score.down}</span>`);
    this.container.attr({
      "data-score": score.total,
      "data-up": score.up,
      "data-down": score.down,
      "data-state": state,
      "data-vote": vote,
    });
  }
}
