import Hotkeys from "@/core/hotkeys";
import CurrentPost from "@/models/CurrentPost";
import ToastManager from "@/utility/Toast";

/**
 * Favorite button and hotkeys on the post toolbar.
 * Renders from `CurrentPost.stats`; button state follows the `post:favorite:*` events the model emits.
 */
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
    this.initEvents();
  }

  private initButtons (): void {
    this.buttons.on("click", () => {
      if (this.processing) return;
      this.toggle().catch(() => { /* Reported through danbooru:error */ });
    });
  }

  private initHotkeys (): void {
    Hotkeys.register("favorite", () => {
      ToastManager.dismiss("Favorite added.", "Favorite removed.");
      if (CurrentPost.favorited)
        ToastManager.track(CurrentPost.unfavorite(), "Updating post...", () => "Favorite removed.");
      else
        ToastManager.track(CurrentPost.favorite(), "Updating post...", () => "Favorite added.");
    });

    Hotkeys.register("favorite-add", () => {
      ToastManager.dismiss("Favorite added.", "Favorite removed.");
      if (CurrentPost.favorited) return;
      ToastManager.track(CurrentPost.favorite(), "Updating post...", () => "Favorite added.");
    });

    Hotkeys.register("favorite-del", () => {
      ToastManager.dismiss("Favorite added.", "Favorite removed.");
      if (!CurrentPost.favorited) return;
      ToastManager.track(CurrentPost.unfavorite(), "Updating post...", () => "Favorite removed.");
    });
  }

  private initEvents (): void {
    $(document)
      .on("post:favorite:start", () => { this.setProcessing(true); })
      .on("post:favorite", () => { this.render(); })
      .on("post:favorite:end", () => { this.setProcessing(false); });
  }

  private toggle (): Promise<unknown> {
    return CurrentPost.favorited ? CurrentPost.unfavorite() : CurrentPost.favorite();
  }

  // The attribute drives the pressed-state styling
  private setProcessing (value: boolean): void {
    this.processing = value;
    this.buttons.attr("processing", String(value));
  }


  /* ============================== */
  /* ========= Rendering ========== */
  /* ============================== */

  /** Syncs the favorite state with `CurrentPost.stats`. */
  public render (): void {
    const value = String(CurrentPost.favorited);
    // Both the toolbar button and the image container carry the favorite state
    this.buttons.attr("favorited", value);
    this.imageContainer.attr("data-is-favorited", value);
  }
}
