import Dialog from "@/components/dialog";
import BulkActions from "@/pages/posts/BulkActions";

interface DeletionContext {
  postId: number;
  reason: string;
  /** Deleting for the reason given on the flag: the reason is fixed and the input hidden */
  fromFlag: boolean;
  moveFavorites: boolean;
}

/**
 * "Delete Post" dialog on posts#show, opened by any `.delete-with-reason-link`:
 * the canned reasons in the quick-mod bar, or "Delete with given reason" on a flag notice.
 */
export default class DeleteWithReasonDialog {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: DeleteWithReasonDialog | null = null;
  public static get instance (): DeleteWithReasonDialog {
    if (!DeleteWithReasonDialog._instance)
      DeleteWithReasonDialog._instance = new DeleteWithReasonDialog();
    return DeleteWithReasonDialog._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private dialog: Dialog | null = null;
  private form: JQuery<HTMLFormElement>;
  private labeledInput: JQuery<HTMLElement>;
  private reasonInput: JQuery<HTMLInputElement>;
  /** Absent when no DMail template is configured */
  private dmailOption: JQuery<HTMLInputElement>;
  private okButton: JQuery<HTMLButtonElement>;
  private context: DeletionContext | null = null;

  private constructor () {
    if (DeleteWithReasonDialog._instance)
      throw new Error("DeleteWithReasonDialog is a singleton class. Use DeleteWithReasonDialog.instance to access the instance.");

    this.form = $("#delete-with-reason-dialog");
    if (!this.form.length) return;
    this.labeledInput = this.form.find("#delete-with-reason-dialog-labeled-input");
    this.reasonInput = this.form.find("#delete-with-reason-dialog-input");
    this.dmailOption = this.form.find("#delete-with-reason-dialog-enable-dmail");
    this.okButton = this.form.find("#delete-with-reason-dialog-ok");

    $(".delete-with-reason-link").on("click", (event) => {
      event.preventDefault();
      const data = $(event.currentTarget).data();
      this.open({
        postId: Number(data.postId),
        reason: String(data.reason ?? ""),
        fromFlag: data.fromFlag === true || data.fromFlag === "true",
        moveFavorites: data.moveFavs === true || data.moveFavs === "true",
      });
    });

    this.form.on("submit", (event) => {
      event.preventDefault();
      this.submit();
    });
    this.form.find("#delete-with-reason-dialog-cancel").on("click", () => this.close());
  }

  public get isOpen (): boolean { return this.dialog?.isOpen ?? false; }

  public open (context: DeletionContext): void {
    if (!this.dialog) this.dialog = new Dialog(this.form);
    this.context = context;

    this.labeledInput.prop("hidden", context.fromFlag);
    if (!context.fromFlag) this.reasonInput.val(context.reason);

    // Must come after open(), since the dialog focuses its own wrapper
    this.dialog.open();
    if (context.fromFlag) {
      this.okButton.trigger("focus");
    } else {
      this.reasonInput.trigger("focus");
      // Scroll to the end of the reason so it's faster to append to it
      this.reasonInput.scrollLeft(this.reasonInput[0].scrollWidth);
    }
  }

  public close (): void {
    this.dialog?.close();
  }

  private submit (): void {
    if (!this.context) return;
    const { postId, reason, fromFlag, moveFavorites } = this.context;

    const sendDmail = this.dmailOption.prop("checked") === true;
    void BulkActions.delete(postId, fromFlag ? reason : String(this.reasonInput.val() ?? ""), {
      reload: true,
      from_flag: fromFlag,
      move_favorites: moveFavorites,
      dmail: sendDmail ? String(this.dmailOption.data("dmail-message") ?? "") : null,
      dmail_title: sendDmail ? String(this.dmailOption.data("dmail-title") ?? "") : null,
    });
  }
}
