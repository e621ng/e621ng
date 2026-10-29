import State from "@/utility/StateUtils";
import ToastManager, { Toast } from "@/utility/Toast";

/**
 * Terms of Use modal, rendered by the server until the current TOS version is accepted.
 * The form also works without JS (server-side POST); here it is accepted client-side instead.
 */
export default class TOSWarning {

  public static readonly DeclineMessage = "You must accept the TOU and confirm that you are at least 18 years old to use this site.";

  public static bootstrap (): void {
    const form = document.getElementById("tos-form") as HTMLFormElement | null;
    if (!form) return;

    document.body.classList.add("scroll-lock");
    new TOSWarning(form);
  }

  private form: HTMLFormElement;
  private tosVersion: string;
  private acceptButton: HTMLElement | null;
  private ageCheckbox: HTMLInputElement;
  private termsCheckbox: HTMLInputElement;
  private toast: Toast | null = null;

  constructor (form: HTMLFormElement) {
    this.form = form;
    this.tosVersion = form.dataset.tosVersion ?? "";
    this.acceptButton = document.getElementById("tos-warning-accept");
    this.ageCheckbox = document.getElementById("tos-age-checkbox") as HTMLInputElement;
    this.termsCheckbox = document.getElementById("tos-terms-checkbox") as HTMLInputElement;

    // Undo any form state restored by the browser
    this.ageCheckbox.checked = false;
    this.termsCheckbox.checked = false;
    this.updateAcceptButton();

    this.ageCheckbox.addEventListener("change", () => this.updateAcceptButton());
    this.termsCheckbox.addEventListener("change", () => this.updateAcceptButton());

    this.form.addEventListener("submit", (event) => {
      event.preventDefault();
      if (!this.isAccepted) return;
      this.toast?.dismiss(true);
      this.acceptClientSide();
    });

    document.getElementById("tos-warning-decline")?.addEventListener("click", (event) => {
      event.preventDefault();
      this.toast?.dismiss();
      this.toast = ToastManager.create(TOSWarning.DeclineMessage, { type: "alert" });
    });

    this.ageCheckbox.focus();
    this.ageCheckbox.addEventListener("change", () => this.termsCheckbox.focus(), { once: true });
  }

  private get isAccepted (): boolean {
    return this.ageCheckbox.checked && this.termsCheckbox.checked;
  }

  private acceptClientSide (): void {
    const maxAge = 20 * 365 * 24 * 60 * 60;
    let cookieString = `tos_accepted=${this.tosVersion}; path=/; max-age=${maxAge}; SameSite=Lax`;
    if (location.protocol === "https:")
      cookieString += "; Secure";
    document.cookie = cookieString;

    this.form.closest(".tos-modal-container")?.remove();
    document.body.classList.remove("scroll-lock");
  }

  // Class only: the button must stay clickable for the no-JS fallback
  private updateAcceptButton (): void {
    const disabled = !this.isAccepted;
    this.acceptButton?.classList.toggle("disabled", disabled);
    this.acceptButton?.setAttribute("aria-disabled", String(disabled));
  }
}

State.onReady(() => TOSWarning.bootstrap());
