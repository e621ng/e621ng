import ToastManager from "./Toast";

export default class Flash {
  /* ==== Legacy API ==== */

  public static notice (message: string, permanent: boolean = false): void {
    ToastManager.create(message, { type: "notice", timeout: permanent ? 0 : undefined });
  }

  public static success (message: string, permanent: boolean = false): void {
    ToastManager.create(message, { type: "success", timeout: permanent ? 0 : undefined });
  }

  public static error (message: string): void {
    ToastManager.create(message, { type: "alert", timeout: 0 });
  }

  public static initialize () {
    $(window).on("danbooru:notice", (_event, message) => {
      Flash.notice(message);
    });
    $(window).on("danbooru:error", (_event, message) => {
      ToastManager.get("Updating post...")?.dismiss(true);
      ToastManager.get("Updating posts...")?.dismiss(true);
      Flash.error(message);
    });
  }
}
