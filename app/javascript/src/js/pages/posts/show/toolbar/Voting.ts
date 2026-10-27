import Hotkeys from "@/core/hotkeys";
import CurrentPost from "@/models/CurrentPost";
import { PostVoteResponse } from "@/models/PostVote";
import Offclick, { OffclickEntry } from "@/utility/Offclick";
import ToastManager from "@/utility/Toast";

/** Vote buttons, score breakdown, and the upvote / downvote hotkeys on the post toolbar. */
export default class ToolbarVoting {

  public static init (): void {
    this.initBreakdown();
    this.initButtons();
    this.initHotkeys();
  }

  private static initBreakdown (): void {
    const breakdown = $(".ptbr-breakdown").first();
    let offclick: OffclickEntry | null = null;

    $(".ptbr-score").first().on("click", () => {
      // Register the offclick handler on first use
      if (offclick === null)
        offclick = Offclick.register(".ptbr-score", ".ptbr-breakdown", () => {
          breakdown.addClass("hidden");
        });

      offclick.disabled = !offclick.disabled;
      breakdown.toggleClass("hidden");
    });
  }

  private static initButtons (): void {
    const buttons = $("button.ptbr-vote-button").on("click", (event) => {
      if (buttons.attr("processing") == "true") return;
      buttons.attr("processing", "true");

      const button = $(event.currentTarget);
      button.addClass("anim");

      this.vote(Number(button.data("action")))
        .catch(() => { /* Reported through danbooru:error */ })
        .finally(() => {
          buttons
            .attr("processing", "false")
            .removeClass("anim");
        });
    });
  }

  private static initHotkeys (): void {
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

  /**
   * Casts a vote on the current post and updates the score displays.
   * @param direction 1 for an upvote, -1 for a downvote.
   */
  public static vote (direction: number): Promise<PostVoteResponse> {
    return CurrentPost.vote(direction).then((data) => {
      const state = data.score > 0 ? 1 : (data.score < 0 ? -1 : 0);

      // Score in the information section
      $(".post-score").text(data.score)
        .removeClass("score-negative score-neutral score-positive")
        .addClass(state > 0 ? "score-positive" : (state < 0 ? "score-negative" : "score-neutral"));

      // Toolbar vote block
      $(".ptbr-score").text(data.score);
      $(".ptbr-breakdown").html(`<span>${data.up}</span><span>${data.down}</span>`);
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
