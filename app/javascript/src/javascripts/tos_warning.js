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
    this.declineButton = $("#tos-warning-decline");
    this.ageCheckbox = $("#tos-age-checkbox").prop("checked", false);
    this.termsCheckbox = $("#tos-terms-checkbox").prop("checked", false);

    // Track changes to the checkboxes
    this.ageCheckbox.on("change", () => this.updateAcceptButton());
    this.termsCheckbox.on("change", () => this.updateAcceptButton());

    // Handle accept button click
    this.acceptButton.on("click", (event) => {
      if (this.isAgeChecked && this.isTermsChecked) return;
      event.preventDefault();
      return false;
    });

    // Handle form submission with AJAX
    this.form.on("submit", (event) => this.handleFormSubmit(event));
  }

  // Checkbox states
  get isAgeChecked () { return this.ageCheckbox.is(":checked"); }
  get isTermsChecked () { return this.termsCheckbox.is(":checked"); }

  // Accept button state
  updateAcceptButton () {
    this.acceptButton.toggleClass("disabled", !(this.isAgeChecked && this.isTermsChecked));
  }

  // Handle form submission
  handleFormSubmit (event) {
    event.preventDefault();

    const submitter = event.originalEvent.submitter;
    const action = submitter ? submitter.value : "declined";

    // Ensure that the user accepted the TOS and both checkboxes are checked
    if (action !== "accepted") {
      Danbooru.error("You must accept the Terms of Service to proceed.");
      return false;
    }

    if (!this.isAgeChecked || !this.isTermsChecked) {
      Danbooru.error("You must confirm your age and accept the Terms of Service to proceed.");
      return false;
    }

    // Send AJAX request for acceptance
    $.ajax({
      url: this.form.attr("action") + ".json",
      method: "POST",
      data: {
        state: action,
        age: this.isAgeChecked ? "on" : undefined,
        terms: this.isTermsChecked ? "on" : undefined,
      },
      headers: {
        "X-CSRF-Token": $('meta[name="csrf-token"]').attr("content"),
      },
    }).done((data) => {
      if (data.success) this.hideModal();
      else
        Danbooru.error("TOS acceptance failed: " + data.message);
    }).fail(() => {
      this.form.off("submit");
      this.form.submit();
    });
  }

  // Hide the modal and restore normal page behavior
  hideModal () {
    $("body").removeClass("scroll-lock");
    $(".tos-modal-container").remove();
  }
}

$(() => { TOSWarning.init(); });
