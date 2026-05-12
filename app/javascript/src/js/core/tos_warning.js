class TOSWarning {

  static init () {
    const form = $("#tos-form");
    if (!form.length) return;

    $("body").addClass("scroll-lock");
    new TOSWarning(form);
  }

  constructor (form) {
    this.form = form;
    this.tosVersion = form.data("tos-version");
    this.acceptButton = $("#tos-warning-accept");
    this.ageCheckbox = $("#tos-age-checkbox").prop("checked", false);
    this.termsCheckbox = $("#tos-terms-checkbox").prop("checked", false);

    // Track changes to the checkboxes
    this.ageCheckbox.on("change", () => this.updateAcceptButton());
    this.termsCheckbox.on("change", () => this.updateAcceptButton());

    this.form.on("submit", (event) => {
      event.preventDefault();
      if (!this.isAgeChecked || !this.isTermsChecked) return false;
      this.toast?.dismiss(true);
      this.acceptClientSide();
      return false;
    });

    $("#tos-warning-decline").on("click", (event) => {
      event.preventDefault();
      this.toast?.dismiss();
      this.toast = E621.Toast.create("You must accept the TOU and confirm that you are at least 18 years old to use this site.", { type: "alert" });
      return false;
    });

    // Auto-focus the first checkbox
    this.ageCheckbox.trigger("focus");
    this.ageCheckbox.one("change", () => this.termsCheckbox.trigger("focus"));
  }

  // Checkbox states
  get isAgeChecked () { return this.ageCheckbox.is(":checked"); }
  get isTermsChecked () { return this.termsCheckbox.is(":checked"); }

  acceptClientSide () {
    const maxAge = 20 * 365 * 24 * 60 * 60;
    let cookieString = `tos_accepted=${this.tosVersion}; path=/; max-age=${maxAge}; SameSite=Lax`;
    if (location.protocol === "https:")
      cookieString += "; Secure";
    document.cookie = cookieString;

    this.form.closest(".tos-modal-container").remove();
    $("body").removeClass("scroll-lock");
  }

  // Accept button state
  updateAcceptButton () {
    this.acceptButton.toggleClass("disabled", !(this.isAgeChecked && this.isTermsChecked));
  }
}

$(() => { TOSWarning.init(); });
