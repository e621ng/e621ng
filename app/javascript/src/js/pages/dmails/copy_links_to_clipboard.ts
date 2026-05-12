import Flash from "@/utility/Flash";

class DMails {
  private static url?: string;
  private static catchCopyLinkToClipboardError (error: any, url = this.url) {
    console.warn("Failed! %o", error);
    alert(`Failed to automatically copy sharable link.\n\nLink: ${url}`);
  }

  static init () {
    const shareLink = document.querySelector<HTMLAnchorElement>(`a[href^=${document.location.pathname.replace(/\//g, "\\/")}\\?key]`);
    if (!shareLink) return;
    this.url = shareLink.href;
    shareLink.onclick = (e) => {
      e.preventDefault();
      e.stopImmediatePropagation();
      try {
        navigator.clipboard.writeText(this.url).then(() => Flash.notice("Copied to clipboard!")).catch(() => this.catchCopyLinkToClipboardError);
      } catch (error) {
        this.catchCopyLinkToClipboardError(error);
      }
    };
  }
};

$(() => DMails.init());

export default DMails;
