import Hotkeys from "@/core/hotkeys";
import CurrentPost from "@/models/CurrentPost";
import Favorite from "@/models/Favorite";
import ToastManager from "@/utility/Toast";

/** Favorite button and hotkeys on the post toolbar. */
export default class ToolbarFavorites {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: ToolbarFavorites | null = null;
  public static get instance (): ToolbarFavorites {
    if (!ToolbarFavorites._instance)
      ToolbarFavorites._instance = new ToolbarFavorites();
    return ToolbarFavorites._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private buttons: JQuery<HTMLElement>;
  private imageContainer: JQuery<HTMLElement>;

  /** Whether a favorite request is in flight */
  private processing = false;

  private constructor () {
    if (ToolbarFavorites._instance)
      throw new Error("ToolbarFavorites is a singleton class. Use ToolbarFavorites.instance to access the instance.");

    this.buttons = $(".ptbr-favorite-button");
    this.imageContainer = $("#image-container");

    this.initButtons();
    this.initHotkeys();
  }

  private initButtons (): void {
    this.buttons.on("click", () => {
      if (this.processing) return;
      this.setProcessing(true);

      const request = this.isFavorited() ? this.remove() : this.add();
      request
        .catch(() => { /* Reported through danbooru:error */ })
        .finally(() => { this.setProcessing(false); });
    });
  }

  private initHotkeys (): void {
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


  /* ============================== */
  /* =========== State ============ */
  /* ============================== */

  private isFavorited (): boolean {
    return this.imageContainer.attr("data-is-favorited") == "true";
  }

  // Both the toolbar button and the image container carry the favorite state
  private setFavorited (value: boolean): void {
    this.buttons.attr("favorited", String(value));
    this.imageContainer.attr("data-is-favorited", String(value));
  }

  // The attribute drives the pressed-state styling
  private setProcessing (value: boolean): void {
    this.processing = value;
    this.buttons.attr("processing", String(value));
  }


  /* ============================== */
  /* ========= Public API ========= */
  /* ============================== */

  /** Favorites the current post. */
  public add (): Promise<void> {
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
  public remove (): Promise<void> {
    if (!CurrentPost.exists)
      return Promise.reject(new Error("No current post available for favoriting."));

    return Favorite.destroy(CurrentPost.id, 500).then(() => {
      this.setFavorited(false);
    });
  }
}
