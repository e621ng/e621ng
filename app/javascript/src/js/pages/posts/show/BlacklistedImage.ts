import Blacklist from "@/core/blacklist";

/**
 * Follows the blacklist state of the main image on posts#show:
 * hides the notes and pauses the video while the image is blacklisted,
 * and reveals the image when it is clicked.
 */
export default class BlacklistedImage {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: BlacklistedImage | null = null;
  public static get instance (): BlacklistedImage {
    if (!BlacklistedImage._instance)
      BlacklistedImage._instance = new BlacklistedImage();
    return BlacklistedImage._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private constructor () {
    if (BlacklistedImage._instance)
      throw new Error("BlacklistedImage is a singleton class. Use BlacklistedImage.instance to access the instance.");

    const $container = $("#image-container");
    if (!$container.length) return;

    const sync = (hidden: boolean) => {
      $("#note-container").css("visibility", hidden ? "hidden" : "visible");
      if (!hidden) return;
      const video = $container.find("video")[0] as HTMLVideoElement | undefined;
      video?.pause();
    };

    $container
      .on("blk:hide.blacklistedImage", () => sync(true))
      .on("blk:show.blacklistedImage", () => sync(false))
      .on("click.blacklistedImage", () => {
        if (!$container.hasClass("blacklisted")) return;
        Blacklist.reveal(parseInt($container.attr("data-id") || "") || 0);
      });

    // The first blacklist commit may happen before or after this point
    sync($container.hasClass("blacklisted"));
  }
}
