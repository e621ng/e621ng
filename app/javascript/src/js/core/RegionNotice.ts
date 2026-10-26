import State from "@/utility/StateUtils";
import CStorage from "@/utility/storage/Cookie";

/**
 * Region-specific notice, rendered by the server only when it should be shown.
 * Closing it in any way (button, Esc) sets a cookie that suppresses it from then on.
 */
export default class RegionNotice {

  public static bootstrap (): void {
    const dialog = document.getElementById("region-notice") as HTMLDialogElement | null;
    if (!dialog) return;

    dialog.addEventListener("close", () => {
      CStorage.Site.HideRegionNotice = true;
    }, { once: true });

    document.getElementById("region-notice-close")?.addEventListener("click", () => dialog.close());

    if (typeof dialog.showModal === "function") dialog.showModal();
    else dialog.setAttribute("open", "");
  }
}

State.onReady(() => RegionNotice.bootstrap());
