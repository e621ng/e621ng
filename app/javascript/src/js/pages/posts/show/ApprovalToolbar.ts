import CStorage from "@/utility/storage/Cookie";

/**
 * The "Approvals: On/Off" subnav link on a pending posts#show,
 * which reveals the quick-mod bar inside the pending notice.
 * The server renders the initial state from the same cookie.
 */
export default class ApprovalToolbar {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: ApprovalToolbar | null = null;
  public static get instance (): ApprovalToolbar {
    if (!ApprovalToolbar._instance)
      ApprovalToolbar._instance = new ApprovalToolbar();
    return ApprovalToolbar._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private toggle: JQuery<HTMLElement>;
  private notice: JQuery<HTMLElement>;

  private constructor () {
    if (ApprovalToolbar._instance)
      throw new Error("ApprovalToolbar is a singleton class. Use ApprovalToolbar.instance to access the instance.");

    this.toggle = $("#janitor-toolbar-toggle");
    if (!this.toggle.length) return;
    this.notice = $("#pending-approval-notice");

    this.toggle.on("click", (event) => {
      event.preventDefault();
      this.visible = !this.visible;
    });
  }

  public get visible (): boolean { return CStorage.Posts.JanitorToolbar; }
  public set visible (value: boolean) {
    CStorage.Posts.JanitorToolbar = value;
    this.notice.toggleClass("enabled", value);
    this.toggle.text(value ? "Approvals: On" : "Approvals: Off");
  }
}
