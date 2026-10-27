import Hotkeys from "@/core/hotkeys";
import CurrentPost from "@/models/CurrentPost";
import { PostVoteResponse } from "@/models/PostVote";
import Offclick, { OffclickEntry } from "@/utility/Offclick";
import ToastManager from "@/utility/Toast";

/** Vote buttons, score breakdown, and the upvote / downvote hotkeys on the post toolbar. */
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

  private buttons: JQuery<HTMLElement>;
  private breakdown: JQuery<HTMLElement>;
  private breakdownOffclick: OffclickEntry | null = null;

  /** Whether a vote request is in flight */
  private processing = false;

  private constructor () {
    if (ToolbarVoting._instance)
      throw new Error("ToolbarVoting is a singleton class. Use ToolbarVoting.instance to access the instance.");

    this.buttons = $("button.ptbr-vote-button");
    this.breakdown = $(".ptbr-breakdown").first();

    this.initBreakdown();
    this.initButtons();
    this.initHotkeys();
  }

  private initBreakdown (): void {
    $(".ptbr-score").first().on("click", () => {
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
      this.setProcessing(true);

      const button = $(event.currentTarget);
      button.addClass("anim");

      this.vote(Number(button.data("action")))
        .catch(() => { /* Reported through danbooru:error */ })
        .finally(() => {
          this.setProcessing(false);
          this.buttons.removeClass("anim");
        });
    });
  }

  private initHotkeys (): void {
    Hotkeys.register("upvote", () => {
      ToastManager.dismiss("Post upvoted.", "Post downvoted.");
      ToastManager.track(this.vote(1), "Updating post...", (data) => {
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
      ToastManager.track(this.vote(-1), "Updating post...", (data) => {
        switch (data.our_score) {
          case -1: return "Post downvoted.";
          case 0: return "Downvote removed.";
          default: return "This should not happen.";
        }
      });
    });
  }

  // The attribute drives the pressed-state styling
  private setProcessing (value: boolean): void {
    this.processing = value;
    this.buttons.attr("processing", String(value));
  }


  /* ============================== */
  /* ========= Public API ========= */
  /* ============================== */

  /**
   * Casts a vote on the current post and updates the score displays.
   * @param direction 1 for an upvote, -1 for a downvote.
   */
  public vote (direction: number): Promise<PostVoteResponse> {
    return CurrentPost.vote(direction).then((data) => {
      const state = data.score > 0 ? 1 : (data.score < 0 ? -1 : 0);

      // Score in the information section
      $(".post-score").text(data.score)
        .removeClass("score-negative score-neutral score-positive")
        .addClass(state > 0 ? "score-positive" : (state < 0 ? "score-negative" : "score-neutral"));

      // Toolbar vote block
      $(".ptbr-score").text(data.score);
      this.breakdown.html(`<span>${data.up}</span><span>${data.down}</span>`);
      $(".ptbr-vote").attr({
        "data-score": data.score,
        "data-up": data.up,
        "data-down": data.down,
        "data-state": state,
        "data-vote": data.our_score,
      });

      return data;
    });
  }
}
