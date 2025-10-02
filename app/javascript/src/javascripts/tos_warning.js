class TOSWarning {

  static init () {
    const form = $("#tos-form");
    if (!form.length) return;

    $("body").addClass("scroll-lock");
    new TOSWarning(form);
  }

  constructor (form) {
    this.form = form;
    this.acceptButton = $("#tos-warning-accept");
    this.ageCheckbox = $("#tos-age-checkbox").prop("checked", false);
    this.termsCheckbox = $("#tos-terms-checkbox").prop("checked", false);

    // Track changes to the checkboxes
    this.ageCheckbox.on("change", () => this.updateAcceptButton());
    this.termsCheckbox.on("change", () => this.updateAcceptButton());

    // Disable the accept button if the checkboxes are not checked
    this.acceptButton.on("click", (event) => {
      if (this.isAgeChecked && this.isTermsChecked) return;
      event.preventDefault();
      return false;
    });
  }

  // Checkbox states
  get isAgeChecked () { return this.ageCheckbox.is(":checked"); }
  get isTermsChecked () { return this.termsCheckbox.is(":checked"); }

  // Accept button state
  updateAcceptButton () {
    this.acceptButton.toggleClass("disabled", !(this.isAgeChecked && this.isTermsChecked));
  }
}

$(() => { TOSWarning.init(); });
