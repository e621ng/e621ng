import Dialog from "@/components/dialog";
import BulkActions from "@/pages/posts/BulkActions";
import Page from "@/utility/Page";

/**
 * "Disapprove" dialog on posts#show, opened by the `.detailed-rejection-link` in the quick-mod bar.
 * Lets the approver pick a reason and leave a message for the uploader.
 */
export default class DetailedRejectionDialog {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: DetailedRejectionDialog | null = null;
  public static get instance (): DetailedRejectionDialog {
    if (!DetailedRejectionDialog._instance)
      DetailedRejectionDialog._instance = new DetailedRejectionDialog();
    return DetailedRejectionDialog._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private dialog: Dialog | null = null;
  private container: JQuery<HTMLElement>;
  private form: JQuery<HTMLFormElement>;
  private postIdInput: JQuery<HTMLInputElement>;
  private reasonSelect: JQuery<HTMLSelectElement>;
  private messageInput: JQuery<HTMLInputElement>;
  private postId = 0;

  private constructor () {
    if (DetailedRejectionDialog._instance)
      throw new Error("DetailedRejectionDialog is a singleton class. Use DetailedRejectionDialog.instance to access the instance.");

    if (!Page.matches("posts", "show")) return;

    this.container = $("#detailed-rejection-dialog");
    if (!this.container.length) return;
    this.form = this.container.find("form");
    this.postIdInput = this.form.find("#post_disapproval_post_id");
    this.reasonSelect = this.form.find("#post_disapproval_reason");
    this.messageInput = this.form.find("#post_disapproval_message");

    $(".detailed-rejection-link").on("click", (event) => {
      event.preventDefault();
      this.open(Number($(event.currentTarget).data("post-id")));
    });

    this.form.on("submit", (event) => {
      event.preventDefault();
      this.submit();
    });
    this.container.find("#detailed-rejection-cancel").on("click", () => this.close());
  }

  public get isOpen (): boolean { return this.dialog?.isOpen ?? false; }

  /** Opens the dialog with a clean form for the given post */
  public open (postId: number): void {
    if (!this.dialog) this.dialog = new Dialog(this.container);

    this.postId = postId;
    this.form[0].reset();
    this.postIdInput.val(postId);

    this.dialog.open();
    this.reasonSelect.trigger("focus");
  }

  public close (): void {
    this.dialog?.close();
  }

  private submit (): void {
    const reason = String(this.reasonSelect.val() ?? "");
    const message = String(this.messageInput.val() ?? "");
    void BulkActions.disapprove(this.postId, reason, message);
    this.close();
  }
}
