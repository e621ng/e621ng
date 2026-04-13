import ImmersiveInput from "@/components/ImmersiveInput";
import User from "@/models/User";
import Page from "@/utility/page";

export default class AuthOverlay {

  private $overlay: JQuery<HTMLElement>;

  constructor () {
    this.$overlay = $("<div id='auth-overlay' class='hidden'>")
      .appendTo("body")
      .on("click", (event) => {
        if (event.target !== this.$overlay[0]) return;
        this.isOverlayHidden = true;
      });

    let isAlreadyRendered = false;
    $(".auth-login-link").on("click", async (event) => {
      event.preventDefault();

      if (!isAlreadyRendered) {
        this.$overlay.html("");
        const $form = await this.renderLoginForm();
        $form.prepend(this.renderCloseButton());
        $form.find("#session_url").val(this.getPathWithParams());
  
        this.$overlay.append($form);
        this.bootstrapImmersiveInputs();
        this.bootstrapFormSubmission();
        isAlreadyRendered = true;
      }

      this.isOverlayHidden = !this.isOverlayHidden;

      // Focus on first input if overlay is open
      if (!this.isOverlayHidden) {
        setTimeout(() => {
          this.$overlay.find("input[type=text], input[type=password], input[type=email]").first().focus();
        }, 100);
      }
    });
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
  }


  // ============================== //
  // ======== Form Loading ======== //
  // ============================== //

  private async renderLoginForm (): Promise<JQuery<HTMLElement>> {
    return new Promise((resolve, reject) => {
      $.ajax({
        url: "/auth/login",
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
  };

  private renderCloseButton () {
    return $("<button type='button' class='st-button close-button'>&times;</button>")
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
      this.$overlay.find("#auth-error").text("");

      const $form = $(event.currentTarget);
      $.ajax({
        url: $form.attr("action")!,
        method: $form.attr("method")!,
        data: $form.serialize(),
        dataType: "json",
        timeout: 10000,
        success: (response: { url: string }) => {
          window.location.href = response.url;
        },
        error: (xhr) => {
          $form.find("[type=submit]").prop("disabled", false);
          const message = xhr.responseJSON?.error ?? "Login failed. Please try again.";
          this.showError(message);
        },
      });
    });
  }


  // ============================== //
  // ======== Miscellaneous ======= //
  // ============================== //

  getPathWithParams () {
    return window.location.pathname + window.location.search;
  }
}

$(() => {
  if (!User.is.anonymous) return;
  if (Page.matches("users", "new") || Page.matches("sessions")) return;
  new AuthOverlay();
});
