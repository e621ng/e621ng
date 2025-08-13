import Favorite from "../models/Favorite";
import PostVote from "../models/PostVote";
import Post from "../posts";
import Page from "../utility/page";
import LStorage from "../utility/storage";

export default class PostsShowToolbar {

  _currentPost = null;
  
  init() {
    if (!Page.matches("posts", "show")) return;

    this._currentPost = Post.currentPost();
    if (!this._currentPost) {
      console.error("Unable to fetch current post");
      return;
    }

    // Initialize voting
    $(".ptbr-vote").each((_index, element) => {
      this.initVotingButtons($(element));
    });

    // Initialize favorite buttons
    $(".ptbr-favorite-button").each((_index, element) => {
      this.initFavoriteButton($(element));
    });

    // Initialize notes toggle
    $(".ptbr-notes-button").each((_index, element) => {
      this.initNotesToggle($(element));
    });
  }

  // Initialize voting buttons
  initVotingButtons(wrapper) {
    const scoreBlock = wrapper.find(".ptbr-score");

    const buttons = wrapper.find("button.ptbr-vote-button").on("click", (event) => {
      if (buttons.attr("processing") == "true") return;
      buttons.attr("processing", "true");

      const button = $(event.currentTarget);
      button.addClass("anim");

      PostVote.vote(this._currentPost.id, button.data("action")).then((data) => {
        // Update button states for the current voting block.
        scoreBlock.text(data.score).attr("title", `↑ ${data.up} ${data.down} ↓`);
        wrapper.attr({
          "data-score": data.score,
          "data-up": data.up,
          "data-down": data.down,
          "data-state": data.score > 0 ? 1 : (data.score < 0 ? -1 : 0),
          "data-vote": data.our_score,
        });
      }).finally(() => {
        buttons
          .attr("processing", "false")
          .removeClass("anim");
      });
    });
  }

  
  // Favorite button
  initFavoriteButton(button) {
    button.on("click", () => {
      if (button.attr("processing") == "true") return;
      button.attr("processing", "true");

      if (button.attr("favorited") == "true")
        Favorite.destroy(this._currentPost.id)
          .then(() => { button.attr("favorited", "false"); })
          .finally(() => { button.attr("processing", "false"); });
      else
        Favorite.create(this._currentPost.id)
          .then(() => { button.attr("favorited", "true"); })
          .finally(() => { button.attr("processing", "false"); });
    });
  }

  // Notes toggle button
  initNotesToggle(button) {
    const container = $("#note-container");
    container.toggleClass("hidden", !LStorage.Posts.Notes);
    button.attr("enabled", LStorage.Posts.Notes);

    button.on("click", () => {
      LStorage.Posts.Notes = !LStorage.Posts.Notes;
      container.toggleClass("hidden", !LStorage.Posts.Notes);
      button.attr("enabled", LStorage.Posts.Notes);
    });
  }

}

$(() => {
  (new PostsShowToolbar).init();
});
