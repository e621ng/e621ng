import Page from "@/utility/Page";
import Flash from "@/utility/Flash";

const Onboarding = {};

Onboarding.init = function () {
  const root = document.getElementById("onboarding-root");
  if (!root) return;

  const userId = parseInt(root.dataset.userId || "0");
  let steps = [];
  let currentStep = 0;

  function loadSteps() {
    return $.ajax({
      type: "GET",
      url: `/onboarding.json`,
      dataType: "json",
    })
      .done(data => {
        steps = data.steps;
        renderSteps();
        showStep(0);
      })
      .fail(err => {
        Flash.error(`Error loading onboarding config: ${err}`);
      });
  }

  function renderSteps() {
    const content = $(".onboarding-content");
    content.empty();

    steps.forEach((step, index) => {
      const stepEl = renderStep(step, index);
      content.append(stepEl);
    });
  }

  function renderStep(step, index) {
    const stepEl = $(`<div class="onboarding-step" id="step-${index}"></div>`);

    const title = $(`<h2>${escapeHtml(step.title)}</h2>`);
    stepEl.append(title);

    if (step.description) {
      const desc = $(`<p>${escapeHtml(step.description)}</p>`);
      stepEl.append(desc);
    }

    switch (step.type) {
      case "blacklist":
        renderBlacklistStep(stepEl, step);
        break;
      case "settings":
        renderSettingsStep(stepEl, step);
        break;
      case "info":
        renderInfoStep(stepEl, step);
        break;
    }

    return stepEl;
  }

  function renderBlacklistStep(stepEl, step) {
    const container = $(`<div class="common-blacklist-tags"></div>`);

    step.options.forEach(tag => {
      const isChecked = step.current_value && step.current_value.includes(tag);
      const checked = isChecked ? "checked" : "";
      const tagEl = $(`
        <div class="tag-option">
          <input type="checkbox" 
                id="tag-${tag}" 
                class="blacklist-checkbox" 
                value="${tag}"
                ${checked}>
          <label for="tag-${tag}">${escapeHtml(tag)}</label>
        </div>
      `);
      container.append(tagEl);
    });

    stepEl.append(container);
  }

  function renderSettingsStep(stepEl, step) {
    step.fields.forEach(field => {
      const isChecked = field.current_value ? "checked" : "";
      const fieldEl = $(`
        <div class="settings-option">
          <label>
            <input type="checkbox" id="${field.id}" ${isChecked}>
            <strong>${escapeHtml(field.label)}</strong>
          </label>
          <p class="help-text">${escapeHtml(field.help_text)}</p>
        </div>
      `);
      stepEl.append(fieldEl);
    });
  }

  function renderInfoStep(stepEl, step) {
    if (step.links && step.links.length > 0) {
      const notice = $(`<div class="notice notice-info"></div>`);
      /* Could have other information here.
      if (step.description) {
        notice.append($(`<p>${escapeHtml(step.description)}</p>`));
      }
      */

      const linksContainer = $(`<div style="display: flex; gap: 10px;"></div>`);
      step.links.forEach(link => {
        const linkEl = $(`
          <a href="${link.href}" class="btn btn-secondary" ${link.target ? `target="${link.target}"` : ""}>
            ${escapeHtml(link.label)}
          </a>
        `);
        linksContainer.append(linkEl);
      });
      notice.append(linksContainer);
      stepEl.append(notice);
    }
  }

  function escapeHtml(text) {
    const map = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#039;",
    };
    return text.replace(/[&<>"']/g, m => map[m]);
  }

  function showStep(step) {
    $(".onboarding-step").each((i, el) => {
      $(el).toggle(i === step);
    });
    const totalSteps = steps.length;
    $("#step-counter").text(`Step ${step + 1} of ${totalSteps}`);
    $("#btn-prev").toggle(step > 0);
    $("#btn-next").toggle(step < totalSteps - 1);
    $("#btn-complete").toggle(step === totalSteps - 1);
  }

  function saveCurrentStep() {
    // Save settings for blacklist and settings steps
    if (steps[currentStep] && (steps[currentStep].type === "blacklist" || steps[currentStep].type === "settings")) {
      updateSettings();
    }
  }

  function updateSettings() {
    const selectedTags = $(".blacklist-checkbox:checked")
      .map((i, el) => $(el).val())
      .get()
      .join("\n");

    const data = {
      user: {
        blacklisted_tags: selectedTags,
      },
    };

    // Add all settings fields
    steps.forEach(step => {
      if (step.type === "settings" && step.fields) {
        step.fields.forEach(field => {
          data.user[field.id] = $(`#${field.id}`).prop("checked");
        });
      }
    });

    return $.ajax({
      type: "PATCH",
      url: `/users/${userId}.json`,
      contentType: "application/json",
      data: JSON.stringify(data),
    }).fail(err => {
      Flash.error(`Error updating settings: ${err}`);
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
          window.location.href = data.redirect_url || "/posts";
        })
        .fail((xhr, status, error) => {
          Flash.error(`Onboarding complete failed: ${error}`);
          window.location.href = "/posts";
        });
    });
  }

  $("#btn-prev").on("click", () => {
    if (currentStep > 0) {
      currentStep--;
      showStep(currentStep);
    }
  });
  
  $("#btn-next").on("click", () => {
    if (currentStep < steps.length - 1) {
      saveCurrentStep();
      currentStep++;
      showStep(currentStep);
    }
  });
  
  $("#btn-skip-all").on("click", () => completeOnboarding());
  
  $("#btn-complete").on("click", () => completeOnboarding());

  // Load steps and initialize
  loadSteps();
};

$(() => {
  if (!Page.matches("onboardings", "show")) return;
  Onboarding.init();
});

export default Onboarding;