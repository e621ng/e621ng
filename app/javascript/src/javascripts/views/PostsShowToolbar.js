import Hotkeys from "../hotkeys";
import Favorite from "../models/Favorite";
import PostVote from "../models/PostVote";
import Post from "../posts";
import Utility from "../utility";
import Page from "../utility/page";
import LStorage from "../utility/storage";

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
    PostsShowToolbar.toggleNotes();
    $(".ptbr-notes-button").each((_index, element) => {
      this.initNotesToggle($(element));
    });

    // Initialize fullscreen menu toggle
    $(".ptbr-fullscreen").each((_index, element) => {
      this.initFullscreenMenuToggle($(element));
    });
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
    Hotkeys.register("upvote", () => { PostsShowToolbar.vote(1); });
    Hotkeys.register("downvote", () => { PostsShowToolbar.vote(-1); });
  }

  static async vote (direction) {
    return PostVote.vote(PostsShowToolbar.currentPost.id, direction).then((data) => {
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
      if (imageEl.attr("data-is-favorited") == "true")
        PostsShowToolbar.deleteFavorite();
      else PostsShowToolbar.addFavorite();
    });

    Hotkeys.register("favorite-add", () => {
      if (imageEl.attr("data-is-favorited") == "true") return;
      PostsShowToolbar.addFavorite();
    });

    Hotkeys.register("favorite-del", () => {
      if (imageEl.attr("data-is-favorited") == "false") return;
      PostsShowToolbar.deleteFavorite();
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


  // Notes toggle button
  initNotesToggle (button) {
    button.on("click", () => {
      LStorage.Posts.Notes = !(button.attr("enabled") == "true");
      PostsShowToolbar.toggleNotes();
    });
  }

  static toggleNotes (visible = LStorage.Posts.Notes) {
    $("#note-container").attr("enabled", visible);
    $(".ptbr-notes-button").attr("enabled", visible);
  }

  // Fullscreen / download menu
  initFullscreenMenuToggle (wrapper) {
    const menu = wrapper.find(".ptbr-fullscreen-menu");
    wrapper.find(".ptbr-fullscreen-toggle").on("click", () => {
      menu.toggleClass("hidden");
    });
  }
}

$(() => {
  (new PostsShowToolbar()).init();
});
