import Dialog from "@/components/dialog";
import CurrentPost from "@/models/CurrentPost";
import HTTP from "@/utility/HTTP";
import Logger from "@/utility/Logger";
import Page from "@/utility/Page";
import ToastManager from "@/utility/Toast";

interface RecentPool {
  id: number;
  name: string;
}

/**
 * "Add to Pool" dialog on posts#show, opened by any `.add-to-pool` trigger
 * (sidebar link, toolbar button, hotkey). Reloads on success so the server
 * renders the updated pool navigation.
 */
export default class AddToPoolDialog {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: AddToPoolDialog | null = null;
  public static get instance (): AddToPoolDialog {
    if (!AddToPoolDialog._instance)
      AddToPoolDialog._instance = new AddToPoolDialog();
    return AddToPoolDialog._instance;
  }

  private static Logger = new Logger("AddToPoolDialog");


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private dialog: Dialog | null = null;
  private form: JQuery<HTMLFormElement>;
  private nameInput: JQuery<HTMLInputElement>;
  private submitButton: JQuery<HTMLButtonElement>;
  private recentBlock: JQuery<HTMLElement>;
  private recentList: JQuery<HTMLElement>;

  private constructor () {
    if (AddToPoolDialog._instance)
      throw new Error("AddToPoolDialog is a singleton class. Use AddToPoolDialog.instance to access the instance.");

    if (!Page.matches("posts", "show")) return;

    this.form = $("#add-to-pool-dialog");
    if (!this.form.length) return;
    this.nameInput = this.form.find("#pool_name");
    this.submitButton = this.form.find("button[type=submit]");
    this.recentBlock = this.form.find(".dialog-recent");
    this.recentList = this.form.find("#recent-pools");

    $(".add-to-pool").on("click", (event) => {
      event.preventDefault();
      this.toggle();
    });

    this.form.on("submit", (event) => {
      event.preventDefault();
      void this.submit();
    });
    this.form.find("button[name=cancel]").on("click", () => this.dialog?.close());

    this.recentList.on("click", "li", (event) => {
      this.nameInput.val($(event.currentTarget).attr("data-value") ?? "").trigger("focus");
    });
  }

  public get isOpen (): boolean { return this.dialog?.isOpen ?? false; }

  public toggle (): void {
    if (!this.dialog) {
      this.dialog = new Dialog(this.form);
      void this.loadRecentPools();
    }
    this.dialog.toggle();
  }

  public close (): void {
    this.dialog?.close();
  }


  /* ============================== */
  /* ========== Requests ========== */
  /* ============================== */

  private async submit (): Promise<void> {
    const name = String(this.nameInput.val() ?? "").trim();
    if (!name) {
      ToastManager.alert("Error: No pool specified");
      return;
    }

    this.submitButton.prop("disabled", true);
    try {
      const body = new URLSearchParams({ pool_name: name, post_id: String(CurrentPost.id) });
      const response = await HTTP.post("/pool_element.json", body);
      if (response.ok) {
        AddToPoolDialog.reloadPage();
        return;
      }
      ToastManager.alert("Error: " + await HTTP.errorMessage(response));
    } catch {
      ToastManager.alert("Error: Request failed");
    } finally {
      this.submitButton.prop("disabled", false);
    }
  }

  /** Pools the user recently added to; a nicety, so failures are only logged */
  private async loadRecentPools (): Promise<void> {
    let pools: RecentPool[];
    try {
      pools = await HTTP.getJSON<RecentPool[]>("/pool_element/recent");
    } catch {
      AddToPoolDialog.Logger.log("Failed to load recent pools");
      return;
    }
    if (!Array.isArray(pools) || pools.length === 0) return;

    this.recentList.empty();
    for (const pool of pools)
      this.recentList.append($("<li>").attr({ "role": "button", "data-value": pool.name }).text(pool.name));
    this.recentBlock.prop("hidden", false);
  }

  private static reloadPage (): void {
    window.location.reload();
  }
}
