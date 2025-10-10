import Hotkeys from "../hotkeys";
import Favorite from "../models/Favorite";
import PostVote from "../models/PostVote";
import NoteManager from "../notes";
import Post from "../posts";
import Utility from "../utility";
import Offclick from "../utility/offclick";
import Page from "../utility/page";

export default class PostsShowToolbar {

  static _currentPost = null;
  static get currentPost () {
    if (!this._currentPost) this._currentPost = Post.currentPost();
    if (!PostsShowToolbar._currentPost) PostsShowToolbar._currentPost = Post.currentPost();
    return PostsShowToolbar._currentPost;
  }


  init () {
    if (!Page.matches("posts", "show")) return;

    // Initialize voting
    this.initVotingButtons();
    this.initVotingHotkeys();

    // Initialize favorite buttons
    $(".ptbr-favorite-button").each((_index, element) => {
      this.initFavoriteButton($(element));
    });
    this.initFavoriteHotkeys();

    // Initialize notes toggle
    const noteToggleButtons = $(".ptbr-notes-button")
      .attr("enabled", NoteManager.enabled + "")
      .on("click", () => { NoteManager.enabled = !NoteManager.enabled; });
    $("#note-container").on("note:visible:true note:visible:false", () => {
      noteToggleButtons.attr("enabled", NoteManager.enabled + "");
    });

    // Initialize fullscreen menu toggle
    this.initOverflowMenu();
  }


  // Initialize voting buttons
  initVotingButtons () {
    const scoreBreakdown = $(".ptbr-breakdown").first();
    $(".ptbr-score").first().on("click", () => {
      scoreBreakdown.toggleClass("hidden");
    });

    const buttons = $("button.ptbr-vote-button").on("click", (event) => {
      if (buttons.attr("processing") == "true") return;
      buttons.attr("processing", "true");

      const button = $(event.currentTarget);
      button.addClass("anim");

      PostsShowToolbar
        .vote(button.data("action"))
        .finally(() => {
          buttons
            .attr("processing", "false")
            .removeClass("anim");
        });
    });
  }

  initVotingHotkeys () {
    Hotkeys.register("upvote", () => {
      Utility.notice("Updating post...");
      PostsShowToolbar.vote(1).then(() => {
        Utility.notice("Post upvoted.");
      });
    });
    Hotkeys.register("downvote", () => {
      Utility.notice("Updating post...");
      PostsShowToolbar.vote(-1).then(() => {
        Utility.notice("Post downvoted.");
      });
    });
  }

  static async vote (direction) {
    return PostVote.vote(PostsShowToolbar.currentPost.id, direction).then((data) => {
      // Update Score in Information
      $(".post-score").text(data.score)
        .removeClass("score-negative score-neutral score-positive")
        .addClass(data.score > 0
          ? "score-positive"
          : (data.score < 0 ? "score-negative" : "score-neutral"));

      // Update button states for the current voting block.
      $(".ptbr-score").text(data.score);
      $(".ptbr-breakdown").html(`<span>${data.up}</span><span>${data.down}</span>`);
      $(".ptbr-vote").attr({
        "data-score": data.score,
        "data-up": data.up,
        "data-down": data.down,
        "data-state": data.score > 0 ? 1 : (data.score < 0 ? -1 : 0),
        "data-vote": data.our_score,
      });
      return data;
    });
  }


  // Favorite button
  initFavoriteButton (button) {
    button.on("click", () => {
      if (button.attr("processing") == "true") return;
      button.attr("processing", "true");

      if (button.attr("favorited") == "true")
        PostsShowToolbar
          .deleteFavorite()
          .finally(() => { button.attr("processing", "false"); });
      else
        PostsShowToolbar
          .addFavorite()
          .finally(() => { button.attr("processing", "false"); });
    });
  }

  initFavoriteHotkeys () {
    const imageEl = $("#image-container");

    Hotkeys.register("favorite", () => {
      Utility.notice("Updating post...");
      if (imageEl.attr("data-is-favorited") == "true")
        PostsShowToolbar.deleteFavorite().then(() => Utility.notice("Favorite removed."));
      else PostsShowToolbar.addFavorite().then(() => Utility.notice("Favorite added."));
    });

    Hotkeys.register("favorite-add", () => {
      if (imageEl.attr("data-is-favorited") == "true") return;
      Utility.notice("Updating post...");
      PostsShowToolbar.addFavorite().then(() => Utility.notice("Favorite added."));
    });

    Hotkeys.register("favorite-del", () => {
      if (imageEl.attr("data-is-favorited") == "false") return;
      Utility.notice("Updating post...");
      PostsShowToolbar.deleteFavorite().then(() => Utility.notice("Favorite removed."));
    });
  }

  static async addFavorite () {
    return Favorite.create(PostsShowToolbar.currentPost.id)
      .then(() => {
        $(".ptbr-favorite-button").attr("favorited", "true");
        $("#image-container").attr("data-is-favorited", "true");
      });
  }

  static async deleteFavorite () {
    return Favorite.destroy(PostsShowToolbar.currentPost.id)
      .then(() => {
        $(".ptbr-favorite-button").attr("favorited", "false");
        $("#image-container").attr("data-is-favorited", "false");
      });
  }

  // Fullscreen / download menu
  initOverflowMenu () {
    const menu = $(".ptbr-etc-menu");
    let offclickHandler = null;
    $(".ptbr-etc-toggle").on("click", () => {
      // Register offclick handler on the first use
      if (offclickHandler === null)
        offclickHandler = Offclick.register(".ptbr-etc-toggle", ".ptbr-etc-menu", () => {
          menu.addClass("hidden");
        });

      offclickHandler.disabled = !offclickHandler.disabled;
      menu.toggleClass("hidden", offclickHandler.disabled);
    });

    const button = $(".ptbr-etc-download").on("click.e6.prepare", async (event) => {
      event.preventDefault();

      if (button.attr("pending") == "true") return;
      button.attr("pending", "true");

      const url = PostsShowToolbar.currentPost.file.url;
      console.log("downloading", url);

      fetch(url, {
        mode: "cors",
      })
        .then(response => response.blob())
        .then(blob => {
          let blobUrl = window.URL.createObjectURL(blob);
          button.attr({
            href: blobUrl,
            pending: "false",
          }).off("click.e6.prepare");
          button[0].click();
        })
        .catch(e => {
          Utility.error("Failed to download post file.", e);
          button.attr("pending", "false");
        })
        .finally(() => {
          offclickHandler.disabled = true;
          menu.addClass("hidden");
        });
    });

    $(".ptbr-etc-pool, .ptbr-etc-set").on("click", () => {
      offclickHandler.disabled = true;
      menu.addClass("hidden");
    });
  }
}

$(() => {
  (new PostsShowToolbar()).init();
});
