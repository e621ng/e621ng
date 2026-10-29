import CurrentUser from "@/models/CurrentUser";
import Dialog from "@/components/dialog";

/** The "edit blacklist" dialog in the posts sidebar, also used on uploads#new and post favorites. */
export default class BlacklistQuickEdit {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: BlacklistQuickEdit | null = null;
  public static get instance (): BlacklistQuickEdit {
    if (!BlacklistQuickEdit._instance)
      BlacklistQuickEdit._instance = new BlacklistQuickEdit();
    return BlacklistQuickEdit._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private constructor () {
    if (BlacklistQuickEdit._instance)
      throw new Error("BlacklistQuickEdit is a singleton class. Use BlacklistQuickEdit.instance to access the instance.");

    const dialogEl = $("#blacklist-edit-dialog");
    if (!dialogEl.length) return;

    const windowWidth = $(window).width(),
      windowHeight = $(window).height();

    const dialog = new Dialog(dialogEl, {
      width: windowWidth > 400 ? 400 : windowWidth,
      height: windowHeight > 400 ? 400 : windowHeight,
    });

    $("#blacklist-cancel").on("click", function () {
      dialog.close();
    });

    $("#blacklist-save").on("click", function () {
      const blacklist_content = $("#blacklist-edit").val() + "";
      const blacklist_json = blacklist_content.split(/\n\r?/);
      CurrentUser.blacklist = blacklist_json;
      dialog.close();
    });

    $("#blacklist-edit-link").on("click", function (event) {
      event.preventDefault();
      $("#blacklist-edit").val(CurrentUser.blacklist.join("\n"));
      dialog.open();
    });

    // Update the textarea if the blacklist gets updated elsewhere
    document.addEventListener("e621:blacklistUpdated", (event: CustomEvent<{ blacklist: string[] }>) => {
      const blacklist = event.detail.blacklist;
      $("#blacklist-edit").val(blacklist.join("\n"));
    });
  }
}
