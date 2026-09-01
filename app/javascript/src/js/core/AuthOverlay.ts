import ImmersiveInput from "@/components/ImmersiveInput";
import CurrentUser from "@/models/CurrentUser";
import Page from "@/utility/Page";

export default class AuthOverlay {

  private $overlay: JQuery<HTMLElement>;

  constructor () {
    this.$overlay = $("<div id='auth-overlay' class='hidden'>")
      .appendTo("body")
      .on("mousedown", (event) => {
        if (event.target !== this.$overlay[0]) return;
        this.isOverlayHidden = true;
      });

    let isAlreadyRendered = false;
    let isLoadingForm = false;
    $(".auth-login-link").on("click", async (event) => {
      // Only trigger on plain clicks (not modified with ctrl/cmd/shift/alt)
      if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
      event.preventDefault();

      if (!isAlreadyRendered) {
        if (isLoadingForm) {
          this.isOverlayHidden = false;
          return;
        }

        isLoadingForm = true;
        this.showLoadingState();
        this.isOverlayHidden = false;

        const success = await this.loadLoginForm();
        isLoadingForm = false;

        if (!success) {
          isAlreadyRendered = true;
          window.location.href = $(event.currentTarget).attr("href");
          return;
        }

        isAlreadyRendered = true;
        this.focusFirstInput();
        return;
      }

      this.isOverlayHidden = !this.isOverlayHidden;

      // Focus on first input if overlay is open
      if (!this.isOverlayHidden)
        this.focusFirstInput();
    });
  }

  private loadLoginForm (): Promise<boolean> {
    return this.loadForm("/auth/login");
  }

  private loadForm (url: string): Promise<boolean> {
    return this.fetchForm(url).then(
      ($form) => {
        $form.prepend(this.renderCloseButton());
        $form.find("#session_url").val(this.getPathWithParams());

        this.$overlay.html(""); // Clear loading state
        this.$overlay.append($form);
        this.bootstrapImmersiveInputs();
        this.bootstrapFormSubmission();
        return true;
      },
      (error) => {
        console.error("Auth overlay: failed to load content", error);
        return false;
      },
    );
  }

  /**
   * Swaps the overlay content for the 2FA challenge form after the password step
   * reported `totp_required`. Falls back to the full-page challenge if the form
   * cannot be loaded.
   */
  private async showTotpChallenge (fallbackUrl: string) {
    this.showLoadingState();
    const success = await this.loadForm("/auth/totp");
    if (!success) {
      window.location.href = fallbackUrl;
      return;
    }
    this.focusFirstInput();
  }

  /**
   * The 2FA challenge timed out; swap back to the login form so the user can
   * restart instead of hitting a dead end.
   */
  private async restartExpiredLogin (message: string) {
    this.showLoadingState();
    const success = await this.loadForm("/auth/login");
    if (!success) {
      window.location.href = "/session/new";
      return;
    }
    this.focusFirstInput();
    this.showError(message);
  }


  // ============================== //
  // ======== Getter Magic ======== //
  // ============================== //

  private _overlayHidden = true;

  private get isOverlayHidden () {
    return this._overlayHidden;
  }

  private set isOverlayHidden (value: boolean) {
    this._overlayHidden = value;
    this.$overlay.toggleClass("hidden", value);
    $(document).off("keydown.auth-overlay");

    if (!value) $(document).on("keydown.auth-overlay", (event) => {
      if (event.key !== "Escape") return;
      this.isOverlayHidden = true;
    });
  }


  // ============================== //
  // ======== Form Loading ======== //
  // ============================== //

  private focusFirstInput () {
    setTimeout(() => {
      this.$overlay.find("input[type=text], input[type=password], input[type=email]").first().focus();
    }, 100);
  }

  private showLoadingState () {
    this.$overlay.html(`
      <div class='auth-overlay-loading' role='status' aria-live='polite' aria-busy='true'>
        <p>Loading...</p>
      </div>
    `);
  }

  private fetchForm (url: string): Promise<JQuery<HTMLElement>> {
    return new Promise((resolve, reject) => {
      $.ajax({
        url: url,
        dataType: "html",
        timeout: 10000,
        success: (html) => {
          const $html = $(html);
          resolve($html);
        },
        error: () => {
          console.error("Auth overlay: failed to load content");
          reject();
        },
      });
    });
  }

  private renderCloseButton () {
    return $("<button type='button' class='st-button close-button'>&times;</button>")
      .attr({
        "aria-label": "Close",
        "aria-controls": "auth-overlay",
        "title": "Close",
      })
      .on("click", () => this.isOverlayHidden = true);
  }

  private bootstrapImmersiveInputs () {
    for (const input of this.$overlay.find(".st-immersive-input > input"))
      new ImmersiveInput($(input as HTMLInputElement));
  }


  // ============================== //
  // ======= Form Processing ====== //
  // ============================== //

  private showError (message: string) {
    this.$overlay.find("#auth-error").text(message);
  }

  private bootstrapFormSubmission () {
    this.$overlay.find("form").on("submit", (event) => {
      event.preventDefault();
      const $form = $(event.currentTarget);
      const submitButton = $form.find("[type=submit]").prop("disabled", true);

      // If there is an existing message, leave an empty line to prevent layout shifts
      const errorMessage = this.$overlay.find("#auth-error");
      if (errorMessage.text().length > 0) errorMessage.html("&nbsp;");

      // Check for empty fields before submitting
      const emptyFields = $form.find("input[required]").filter((_, input) => !$(input).val());
      if (emptyFields.length > 0) {
        this.showError("Please fill in all required fields.");
        submitButton.prop("disabled", false);
        emptyFields.first().trigger("focus");
        return false;
      }

      // Submit form via AJAX
      $.ajax({
        url: $form.attr("action")!,
        method: $form.attr("method")!,
        data: $form.serialize(),
        dataType: "json",
        timeout: 3000,
        success: (response: { url: string }) => {
          window.location.href = response.url;
        },
        error: (xhr) => {
          submitButton.prop("disabled", false);

          // Password accepted, but the account has 2FA: swap in the challenge form.
          if (xhr.responseJSON?.code === "totp_required") {
            void this.showTotpChallenge(xhr.responseJSON?.url ?? "/session/totp");
            return;
          }

          // The 2FA challenge timed out: restart from the login form.
          if (xhr.responseJSON?.code === "challenge_expired") {
            void this.restartExpiredLogin(xhr.responseJSON?.error ?? "Your login attempt has expired. Please log in again.");
            return;
          }

          const message = xhr.responseJSON?.error ?? "Login failed. Please try again.";
          this.showError(message);
        },
      });

      return false;
    });
  }


  // ============================== //
  // ======== Miscellaneous ======= //
  // ============================== //

  private getPathWithParams () {
    return window.location.pathname + window.location.search;
  }
}

$(() => {
  if (!CurrentUser.is.anonymous) return;
  if (Page.matches("users", "new") || Page.matches("sessions")) return;
  new AuthOverlay();
});
