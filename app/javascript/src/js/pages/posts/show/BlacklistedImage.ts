import Blacklist from "@/core/blacklist";

/**
 * Follows the blacklist state of the main image on posts#show:
 * hides the notes and pauses the video while the image is blacklisted,
 * and reveals the image when it is clicked.
 */
$(() => {
  const $container = $("#image-container");
  if (!$container.length) return;

  const sync = (hidden: boolean) => {
    $("#note-container").css("visibility", hidden ? "hidden" : "visible");
    if (!hidden) return;
    const video = $container.find("video")[0] as HTMLVideoElement | undefined;
    video?.pause();
  };

  $container
    .off("blk:hide.blacklistedImage blk:show.blacklistedImage click.blacklistedImage")
    .on("blk:hide.blacklistedImage", () => sync(true))
    .on("blk:show.blacklistedImage", () => sync(false))
    .on("click.blacklistedImage", () => {
      if (!$container.hasClass("blacklisted")) return;
      Blacklist.reveal(parseInt($container.attr("data-id") || "") || 0);
    });

  // The first commit happens before this handler is bound
  sync($container.hasClass("blacklisted"));
});
