import Page from "@/utility/Page";

const Onboarding = {};

Onboarding.init = function () {
  const root = document.getElementById("onboarding-root");
  if (!root) return;

  // this sucks, will find a more robust way to do this in the future
  const userId = parseInt(root.dataset.userId || "0");
  const totalSteps = 5;
  let currentStep = 0;

  function showStep(step) {
    $(".onboarding-step").each((i, el) => {
      $(el).toggle(i === step);
    });
    $("#step-counter").text(`Step ${step + 1} of ${totalSteps}`);
    $("#btn-prev").toggle(step > 0);
    $("#btn-next").toggle(step < totalSteps - 1);
    $("#btn-complete").toggle(step === totalSteps - 1);
  }

  function saveCurrentStep() {
    // Trigger save on Step 0 (Blacklist), 1 (Privacy), or 2 (Notifications)
    if (currentStep >= 0 && currentStep <= 2) {
      updateSettings();
    }
  }

  function updateSettings() {
    const selectedTags = $(".blacklist-checkbox:checked")
      .map((i, el) => $(el).val())
      .get()
      .join("\n");

    return $.ajax({
      type: "PATCH",
      url: `/users/${userId}.json`,
      contentType: "application/json",
      data: JSON.stringify({
        user: {
          blacklisted_tags: selectedTags, 
          enable_privacy_mode: $("#enable_privacy_mode").prop("checked"),
          disable_user_dmails: $("#disable_user_dmails").prop("checked"),
          receive_email_notifications: $("#receive_email_notifications").prop("checked"),
        },
      }),
    }).fail(err => {
      console.error("Error updating settings:", err);
    });
  }

  function completeOnboarding() {
    updateSettings().then(() => {
      $.ajax({
        type: "POST",
        url: "/onboarding/complete.json",
        contentType: "application/json",
        dataType: "json",
        data: JSON.stringify({}),
      })
        .done(data => { 
          console.log("Onboarding complete response:", data);
          window.location.href = data.redirect_url || "/posts"; 
        })
        .fail((xhr, status, error) => { 
          console.error("Onboarding complete failed:", status, error, xhr.responseText);
          window.location.href = "/posts"; 
        });
    });
  }

  $("#btn-prev").on("click", () => {
    if (currentStep > 0) { currentStep--; showStep(currentStep); }
  });
  $("#btn-next").on("click", () => {
    if (currentStep < totalSteps - 1) { saveCurrentStep(); currentStep++; showStep(currentStep); }
  });
  $("#btn-skip").on("click", () => {
    if (currentStep < totalSteps - 1) { currentStep++; showStep(currentStep); }
  });
  $("#btn-skip-all").on("click", () => completeOnboarding());
  $("#btn-complete").on("click", () => completeOnboarding());
};

$(() => {
  if (!Page.matches("onboardings", "show")) return;
  Onboarding.init();
});

export default Onboarding;