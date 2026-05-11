import Hotkeys from "@/core/hotkeys";
import Favorite from "@/models/Favorite";
import PostVote from "@/models/PostVote";
import NoteManager from "@/pages/posts/show/notes";
import Post from "@/pages/posts/posts";
import Offclick from "@/utility/Offclick";
import Page from "@/utility/Page";
import ToastManager from "@/utility/Toast";

export default class PostsShowToolbar {

  static _currentPost = null;
  static get currentPost () {
    if (!this._currentPost) this._currentPost = Post.currentPost();
    if (!PostsShowToolbar._currentPost) PostsShowToolbar._currentPost = Post.currentPost();
    return PostsShowToolbar._currentPost;
  }


  init () {
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
      .attr({
        "enabled": NoteManager.enabled + "",
        "aria-pressed": NoteManager.enabled + "",
      })
      .on("click", () => { NoteManager.enabled = !NoteManager.enabled; });
    $("#note-container").on("note:visible:true note:visible:false", () => {
      noteToggleButtons.attr({
        "enabled": NoteManager.enabled + "",
        "aria-pressed": NoteManager.enabled + "",
      });
    });

    // Initialize fullscreen menu toggle
    this.initOverflowMenu();

    // Initialize share button
    $(".ptbr-share-button").on("click", () => {
      $("#ptbr-share-menu").toggleClass("hidden");
    });

    $(".ptbr-share-link").on("click", function () {
      $(this).trigger("select");
    });

    $(".ptbr-share-copy").on("click", (event) => {
      const button = $(event.currentTarget);
      const value = button.data("value");
      navigator.clipboard.writeText(value).then(() => {
        E621.Toast.notice("Link copied to clipboard.");
      }).catch((e) => {
        E621.Toast.alert("Failed to copy link to clipboard.", e);
      });
    });
  }


  // Initialize voting buttons
  initVotingButtons () {
    const scoreBreakdown = $(".ptbr-breakdown").first();
    let scoreOffclick = null;
    $(".ptbr-score").first().on("click", () => {
      // Register offclick handler on the first use
      if (scoreOffclick === null)
        scoreOffclick = Offclick.register(".ptbr-score", ".ptbr-breakdown", () => {
          scoreBreakdown.addClass("hidden");
        });

      scoreOffclick.disabled = !scoreOffclick.disabled;
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
      ToastManager.dismiss("Post upvoted.", "Post downvoted.");
      const toast = E621.Toast.create("Updating post...", { type: "info", timeout: 10 });
      PostsShowToolbar.vote(1).then(() => {
        toast.type = "notice";
        toast.message = "Post upvoted.";
        toast.timeout = 1;
      });
    });
    Hotkeys.register("downvote", () => {
      ToastManager.dismiss("Post upvoted.", "Post downvoted.");
      const toast = E621.Toast.create("Updating post...", { type: "info", timeout: 10 });
      PostsShowToolbar.vote(-1).then(() => {
        toast.type = "notice";
        toast.message = "Post downvoted.";
        toast.timeout = 1;
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
      ToastManager.dismiss("Favorite added.", "Favorite removed.");
      const toast = E621.Toast.create("Updating post...", { type: "info", timeout: 10 });
      if (imageEl.attr("data-is-favorited") == "true")
        PostsShowToolbar.deleteFavorite().then(() => {
          toast.type = "notice";
          toast.message = "Favorite removed.";
          toast.timeout = 1;
        });
      else PostsShowToolbar.addFavorite().then(() => {
        toast.type = "notice";
        toast.message = "Favorite added.";
        toast.timeout = 1;
      });
    });

    Hotkeys.register("favorite-add", () => {
      ToastManager.dismiss("Favorite added.", "Favorite removed.");
      if (imageEl.attr("data-is-favorited") == "true") return;
      const toast = E621.Toast.create("Updating post...", { type: "info", timeout: 10 });
      PostsShowToolbar.addFavorite().then(() => {
        toast.type = "notice";
        toast.message = "Favorite added.";
        toast.timeout = 1;
      });
    });

    Hotkeys.register("favorite-del", () => {
      ToastManager.dismiss("Favorite added.", "Favorite removed.");
      if (imageEl.attr("data-is-favorited") == "false") return;
      const toast = E621.Toast.create("Updating post...", { type: "info", timeout: 10 });
      PostsShowToolbar.deleteFavorite().then(() => {
        toast.type = "notice";
        toast.message = "Favorite removed.";
        toast.timeout = 1;
      });
    });
  }

  static async addFavorite () {
    return Favorite.create(PostsShowToolbar.currentPost.id, 500)
      .then(() => {
        $(".ptbr-favorite-button").attr("favorited", "true");
        $("#image-container").attr("data-is-favorited", "true");
      });
  }

  static async deleteFavorite () {
    return Favorite.destroy(PostsShowToolbar.currentPost.id, 500)
      .then(() => {
        $(".ptbr-favorite-button").attr("favorited", "false");
        $("#image-container").attr("data-is-favorited", "false");
      });
  }

  // Fullscreen / download menu
  initOverflowMenu () {
    const menu = $(".ptbr-etc-menu");
    let offclickHandler = null;
    const toggle = $(".ptbr-etc-toggle").on("click", () => {
      // Register offclick handler on the first use
      if (offclickHandler === null)
        offclickHandler = Offclick.register(".ptbr-etc-toggle", ".ptbr-etc-menu", () => {
          menu.addClass("hidden");
          toggle.attr("aria-expanded", false);
        });

      offclickHandler.disabled = !offclickHandler.disabled;
      menu.toggleClass("hidden", offclickHandler.disabled);
      toggle.attr("aria-expanded", !offclickHandler.disabled);
    });

    const button = $(".ptbr-etc-download").on("click.e6.prepare", (event) => {
      event.preventDefault();

      if (button.attr("pending") == "true") return;
      button.attr("pending", "true");

      const url = PostsShowToolbar.currentPost.file.url;

      fetch(url, {
        mode: "cors",
      })
        .then(response => {
          if (!response.ok) throw new Error(`HTTP ${response.status}`);
          return response.blob();
        })
        .then(blob => {
          const blobUrl = window.URL.createObjectURL(blob);
          PostsShowToolbar.generateDownloadLink(blobUrl, button.attr("download"));
          button.attr("pending", "false");
          setTimeout(() => window.URL.revokeObjectURL(blobUrl), 0);
        })
        .catch(e => {
          E621.Toast.alert("Failed to download post file: " + e.message, e);
          button.attr("pending", "false");
        })
        .finally(() => {
          offclickHandler.disabled = true;
          menu.addClass("hidden");
        });
    });

    $(".ptbr-etc-pool, .ptbr-etc-set, .ptbr-share-button").on("click", () => {
      offclickHandler.disabled = true;
      menu.addClass("hidden");
    });
  }

  static generateDownloadLink (blobUrl, fileName) {
    // I will take a download link... and CLICK IT!!!
    const downloadLink = document.createElement("a");
    downloadLink.href = blobUrl;
    downloadLink.setAttribute("download", fileName);
    document.body.appendChild(downloadLink);
    downloadLink.click();
    downloadLink.remove();
  }
}

$(() => {
  if (!Page.matches("posts", "show")) return;
  (new PostsShowToolbar()).init();
});
