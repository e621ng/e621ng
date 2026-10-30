import Dialog from "@/components/dialog";
import CurrentPost from "@/models/CurrentPost";
import PostSet from "@/models/PostSet";
import HTTP from "@/utility/HTTP";
import ToastManager from "@/utility/Toast";

/**
 * "Add to Set" dialog on posts#show, opened by any `.add-to-set` trigger
 * (sidebar link, toolbar button, hotkey). Reloads on success so the server
 * renders the updated set navigation.
 */
export default class AddToSetDialog {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: AddToSetDialog | null = null;
  public static get instance (): AddToSetDialog {
    if (!AddToSetDialog._instance)
      AddToSetDialog._instance = new AddToSetDialog();
    return AddToSetDialog._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private dialog: Dialog | null = null;
  private form: JQuery<HTMLFormElement>;
  private select: JQuery<HTMLSelectElement>;
  private submitButton: JQuery<HTMLButtonElement>;

  private constructor () {
    if (AddToSetDialog._instance)
      throw new Error("AddToSetDialog is a singleton class. Use AddToSetDialog.instance to access the instance.");

    this.form = $("#add-to-set-dialog");
    if (!this.form.length) return;
    this.select = this.form.find("#add-to-set-id");
    this.submitButton = this.form.find("button[type=submit]");

    $(".add-to-set").on("click", (event) => {
      event.preventDefault();
      this.toggle();
    });

    this.form.on("submit", (event) => {
      event.preventDefault();
      void this.submit();
    });
    this.form.find("button[name=cancel]").on("click", () => this.dialog?.close());
  }

  public get isOpen (): boolean { return this.dialog?.isOpen ?? false; }

  public toggle (): void {
    if (!this.dialog) this.dialog = new Dialog(this.form);
    // The set list may have changed in another tab; refresh it on every open
    if (!this.dialog.isOpen) void PostSet.populateSelect(this.select);
    this.dialog.toggle();
  }

  public close (): void {
    this.dialog?.close();
  }


  /* ============================== */
  /* ========== Requests ========== */
  /* ============================== */

  private async submit (): Promise<void> {
    const setId = Number(this.select.val());
    if (!setId || isNaN(setId)) {
      ToastManager.alert("Error: No set specified");
      return;
    }

    this.submitButton.prop("disabled", true);
    try {
      const body = new URLSearchParams({ "post_ids[]": String(CurrentPost.id) });
      const response = await HTTP.post(`/post_sets/${setId}/add_posts.json`, body);
      if (response.ok) {
        AddToSetDialog.reloadPage();
        return;
      }
      ToastManager.alert("Error: " + await HTTP.errorMessage(response));
    } catch {
      ToastManager.alert("Error: Request failed");
    } finally {
      this.submitButton.prop("disabled", false);
    }
  }

  private static reloadPage (): void {
    window.location.reload();
  }
}
