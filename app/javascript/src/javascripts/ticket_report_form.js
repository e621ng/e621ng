// Ticket report form functionality
class TicketReportForm {
  constructor () {
    this.unusualReasons = new Set(["flag", "takedown"]);
    this.init();
  }

  init () {
    const input = document.getElementById("report-reason-input");
    const submit = document.getElementById("ticket_submit");

    if (!input || !submit) return;

    // Bind radio button changes
    document.querySelectorAll(".report-reason-radio").forEach(radio => {
      radio.addEventListener("change", () => {
        this.handleReasonChange(radio, input, submit);
      });
    });

    // Trigger change event for any pre-checked radio
    const checkedRadio = document.querySelector(".report-reason-radio:checked");
    if (checkedRadio) {
      checkedRadio.dispatchEvent(new Event("change"));
    }
  }

  handleReasonChange (radio, input, submit) {
    // Remove selected class from all labels
    document.querySelectorAll(".report-reason-label").forEach(label => {
      label.classList.remove("selected");
    });

    // Add selected class to current label
    const currentLabel = radio.closest(".report-reason-label");
    if (currentLabel) {
      currentLabel.classList.add("selected");
    }

    const reason = radio.value;

    if (this.unusualReasons.has(reason)) {
      // Hide all unusual reason sections
      document.querySelectorAll(".report-unusual").forEach(section => {
        section.style.display = "none";
      });

      // Show the specific reason section
      const reasonSection = document.getElementById("report-reason-" + reason);
      if (reasonSection) {
        reasonSection.style.display = "block";
      }

      // Hide input and submit
      input.style.display = "none";
      submit.style.display = "none";
    } else {
      // Hide all unusual reason sections
      document.querySelectorAll(".report-unusual").forEach(section => {
        section.style.display = "none";
      });

      // Show input and submit
      input.style.display = "block";
      submit.style.display = "block";
    }
  }
}

// Auto-initialize when the page loads
document.addEventListener("DOMContentLoaded", function () {
  // Check if we're on a ticket report form page
  if (document.querySelector(".report-reason-radio")) {
    new TicketReportForm();
  }
});

export default TicketReportForm;
