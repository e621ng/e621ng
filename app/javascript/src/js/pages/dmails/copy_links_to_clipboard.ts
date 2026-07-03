import Toast from "@/utility/Toast";

class DMails {
  static init () {
    if (typeof navigator.clipboard !== "object")
      return; // Clipboard API not supported

    const shareLink = $("#share-link") as JQuery<HTMLAnchorElement>;
    if (!shareLink.length) return;
    const url = shareLink.attr("href");

    shareLink.on("click.copyLink", (event) => {
      event.preventDefault();
      event.stopImmediatePropagation();
      try {
        navigator.clipboard.writeText(url)
          .then(() => Toast.notice("Copied to clipboard!"))
          .catch(() => this.releaseCopyEvent());
      } catch { this.releaseCopyEvent(); }
    });
  }

  // Ungraceful fallback for browsers that do not support the Clipboard API
  private static releaseCopyEvent () {
    $("#share-link")
      .off("click.copyLink")
      .trigger("click");
  }
};

$(() => DMails.init());

export default DMails;
