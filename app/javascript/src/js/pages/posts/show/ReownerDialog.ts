import Dialog from "@/components/dialog";
import CurrentPost from "@/models/CurrentPost";
import HTTP from "@/utility/HTTP";
import ToastManager from "@/utility/Toast";

interface PreviousOwner {
  id: number;
  name: string;
}

/** Select value that reveals the free-form input (admins only) */
const OTHER_OWNER = "0";

/**
 * "Reowner Post" dialog on posts#show, opened by the janitor-only sidebar link.
 * Offers the post's previous uploaders, plus a free-form name/ID for admins.
 */
export default class ReownerDialog {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: ReownerDialog | null = null;
  public static get instance (): ReownerDialog {
    if (!ReownerDialog._instance)
      ReownerDialog._instance = new ReownerDialog();
    return ReownerDialog._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private dialog: Dialog | null = null;
  private form: JQuery<HTMLFormElement>;
  private status: JQuery<HTMLElement>;
  private select: JQuery<HTMLSelectElement>;
  private input: JQuery<HTMLInputElement>;
  /** The option checkboxes are absent for non-BD staff; the server defaults apply */
  private reownerVersions: JQuery<HTMLInputElement>;
  private postEvents: JQuery<HTMLInputElement>;
  private karma: JQuery<HTMLInputElement>;
  private okButton: JQuery<HTMLButtonElement>;

  /** Guards against a slow owner list from an earlier open overwriting a newer one */
  private loadToken = 0;
  private submitting = false;

  private constructor () {
    if (ReownerDialog._instance)
      throw new Error("ReownerDialog is a singleton class. Use ReownerDialog.instance to access the instance.");

    this.form = $("#reowner-dialog");
    if (!this.form.length) return;
    this.status = this.form.find("#reowner-dialog-status");
    this.select = this.form.find("#reowner-dialog-select");
    this.input = this.form.find("#reowner-dialog-input");
    this.reownerVersions = this.form.find("#reowner-dialog-reowner-versions");
    this.postEvents = this.form.find("#reowner-dialog-post-events");
    this.karma = this.form.find("#reowner-dialog-karma");
    this.okButton = this.form.find("#reowner-dialog-ok");

    $("#reowner-post-link").on("click", (event) => {
      event.preventDefault();
      void this.open();
    });

    this.select.on("change", () => this.syncInput());
    this.input.on("input", () => this.syncOkButton());

    this.form.on("submit", (event) => {
      event.preventDefault();
      void this.submit();
    });
    this.form.find("#reowner-dialog-cancel").on("click", () => this.close());
  }

  public get isOpen (): boolean { return this.dialog?.isOpen ?? false; }

  public async open (): Promise<void> {
    if (!this.dialog) this.dialog = new Dialog(this.form);
    const token = ++this.loadToken;

    this.status.text("Loading...");
    this.select.prop("hidden", true).empty();
    this.input.prop("hidden", true).val("");
    this.syncOkButton();
    this.dialog.open();

    const owners = await ReownerDialog.previousOwners();
    if (token !== this.loadToken) return;

    for (const owner of owners)
      this.select.append($("<option>").val(owner.id).text(`${owner.name} (${owner.id})`));
    if (this.select.data("allow-other"))
      this.select.append($("<option>").val(OTHER_OWNER).text("Other..."));

    this.status.text(owners.length ? "" : "No previous owners found.");
    this.select.prop("hidden", owners.length === 0);
    this.syncInput();
  }

  public close (): void {
    this.dialog?.close();
  }

  /** Mirrors the selected owner into the input, or opens the input up for "Other..." */
  private syncInput (): void {
    const value = String(this.select.val() ?? "");
    const isOther = value === OTHER_OWNER;
    this.input.prop({ hidden: !isOther, disabled: !isOther });
    this.input.val(isOther || !value ? "" : `!${value}`);
    if (isOther) this.input.trigger("focus");
    this.syncOkButton();
  }

  private syncOkButton (): void {
    this.okButton.prop("disabled", this.submitting || !this.newOwner);
  }

  private get newOwner (): string {
    return String(this.input.val() ?? "").trim();
  }


  /* ============================== */
  /* ========== Requests ========== */
  /* ============================== */

  private static async previousOwners (): Promise<PreviousOwner[]> {
    try {
      const response = await HTTP.get(`/staff/post/posts/${CurrentPost.id}/previous_owners.json`);
      if (response.ok) return await response.json();
      ToastManager.alert("Error: " + await HTTP.errorMessage(response));
    } catch {
      ToastManager.alert("Error: Request failed");
    }
    return [];
  }

  private async submit (): Promise<void> {
    const newOwner = this.newOwner;
    if (this.submitting || !newOwner) return;

    const body = new URLSearchParams({ "reowner[new_owner]": newOwner });
    const options = { reowner_versions: this.reownerVersions, post_events: this.postEvents, karma: this.karma };
    for (const [name, checkbox] of Object.entries(options))
      if (checkbox.length) body.append(`reowner[${name}]`, String(checkbox.prop("checked") === true));

    this.submitting = true;
    this.syncOkButton();
    try {
      const response = await HTTP.post(`/staff/post/posts/${CurrentPost.id}/reowner.json`, body);
      if (response.ok) {
        ReownerDialog.reloadPage();
        return;
      }
      ToastManager.alert("Error: " + await HTTP.errorMessage(response));
    } catch {
      ToastManager.alert("Error: Request failed");
    } finally {
      this.submitting = false;
      this.syncOkButton();
    }
  }

  private static reloadPage (): void {
    window.location.reload();
  }
}
