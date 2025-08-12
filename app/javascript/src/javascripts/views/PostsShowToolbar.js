import Favorite from "../models/Favorite";
import Post from "../posts";
import Page from "../utility/page";

export default class PostsShowToolbar {

  _currentPost = null;
  
  init() {
    if (!Page.matches("posts", "show")) return;

    this._currentPost = Post.currentPost();
    if (!this._currentPost) {
      console.error("Unable to fetch current post");
      return;
    }

    this.initFavoriteButton();
  }

  /** Initializes the favorite button functionality. */
  initFavoriteButton() {
    const button = $("#ptbr-favorite").on("click", () => {
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

}

$(() => {
  (new PostsShowToolbar).init();
});
