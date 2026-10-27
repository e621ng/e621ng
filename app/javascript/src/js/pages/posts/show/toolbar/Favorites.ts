import Hotkeys from "@/core/hotkeys";
import CurrentPost from "@/models/CurrentPost";
import Favorite from "@/models/Favorite";
import ToastManager from "@/utility/Toast";

/** Favorite button and hotkeys on the post toolbar. */
export default class ToolbarFavorites {

  public static init (): void {
    $(".ptbr-favorite-button").each((_index, element) => {
      this.initButton($(element));
    });
    this.initHotkeys();
  }

  private static initButton (button: JQuery<HTMLElement>): void {
    button.on("click", () => {
      if (button.attr("processing") == "true") return;
      button.attr("processing", "true");

      const request = button.attr("favorited") == "true" ? this.remove() : this.add();
      request
        .catch(() => { /* Reported through danbooru:error */ })
        .finally(() => { button.attr("processing", "false"); });
    });
  }

  private static initHotkeys (): void {
    Hotkeys.register("favorite", () => {
      ToastManager.dismiss("Favorite added.", "Favorite removed.");
      if (this.isFavorited())
        ToastManager.track(this.remove(), "Updating post...", () => "Favorite removed.");
      else
        ToastManager.track(this.add(), "Updating post...", () => "Favorite added.");
    });

    Hotkeys.register("favorite-add", () => {
      ToastManager.dismiss("Favorite added.", "Favorite removed.");
      if (this.isFavorited()) return;
      ToastManager.track(this.add(), "Updating post...", () => "Favorite added.");
    });

    Hotkeys.register("favorite-del", () => {
      ToastManager.dismiss("Favorite added.", "Favorite removed.");
      if (!this.isFavorited()) return;
      ToastManager.track(this.remove(), "Updating post...", () => "Favorite removed.");
    });
  }

  private static isFavorited (): boolean {
    return $("#image-container").attr("data-is-favorited") == "true";
  }

  // Both the toolbar button and the image container carry the favorite state
  private static setFavorited (value: boolean): void {
    $(".ptbr-favorite-button").attr("favorited", String(value));
    $("#image-container").attr("data-is-favorited", String(value));
  }

  /** Favorites the current post. */
  public static add (): Promise<void> {
    if (!CurrentPost.exists)
      return Promise.reject(new Error("No current post available for favoriting."));

    return Favorite.create(CurrentPost.id, 500).then(
      () => { this.setFavorited(true); },
      (error: Error & { cause?: unknown }) => {
        // The server state is what we wanted, so just sync the page
        if (error.cause !== "You have already favorited this post") throw error;
        this.setFavorited(true);
      },
    );
  }

  /** Removes the current post from favorites. */
  public static remove (): Promise<void> {
    if (!CurrentPost.exists)
      return Promise.reject(new Error("No current post available for favoriting."));

    return Favorite.destroy(CurrentPost.id, 500).then(() => {
      this.setFavorited(false);
    });
  }
}
