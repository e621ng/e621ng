import E621Type from "@/interfaces/E621";
import Page from "@/utility/Page";

declare const E621: E621Type;

interface OnboardingLink {
  label: string;
  href: string;
  target?: string;
}

interface OnboardingField {
  id: string;
  label: string;
  help_text: string;
  type: "checkbox";
  current_value?: boolean;
}

interface OnboardingStep {
  id: string;
  title: string;
  description?: string;
  field?: string;
  options?: string[];
  current_value?: string[];
  fields?: OnboardingField[];
  links?: OnboardingLink[];
}

interface OnboardingResponse {
  steps: OnboardingStep[];
}

interface OnboardingCompleteResponse {
  redirect_url?: string;
}

export default class Onboarding {
  private $root: JQuery<HTMLElement>;
  private userId: number
  private steps: OnboardingStep[];
  private currentStep: number;

  constructor(root: HTMLElement) {
    this.$root = $(root);
    this.userId = parseInt(this.$root.data("user-id") || "0");
    this.steps = [];
    this.currentStep = 0;

    $("#btn-prev").on("click", () => {
      if (this.currentStep > 0) {
        this.currentStep--;
        this.showStep(this.currentStep);
      }
    });

    $("#btn-next").on("click", () => {
      if (this.currentStep < this.steps.length - 1) {
        this.saveCurrentStep();
        this.currentStep++;
        this.showStep(this.currentStep);
      }
    });

    $("#btn-skip-all").on("click", () => this.completeOnboarding());

    this.loadSteps();
  }

  private loadSteps(): JQuery.jqXHR {
    return $.ajax({
      type: "GET",
      url: `/onboarding.json`,
      dataType: "json",
    })
      .done((data: OnboardingResponse) => {
        this.steps = data.steps;
        this.renderSteps();
        this.showStep(0);
      })
      .fail(err => {
        E621.Toast.error("Failed to load onboarding steps. Please try again later.");
      });
  }

  private saveCurrentStep() {
    const current = this.steps[this.currentStep];
    if (current && (current.type === "blacklist" || current.type === "settings")) {
      this.updateSettings();
    }
  }

  private updateSettings(): JQuery.jqXHR {
    const selectedTags = $(".blacklist-checkbox:checked")
      .map((i, el) => $(el).val())
      .get()
      .join("\n");
    
    const userData: Record<string, string | boolean> = {
      blacklisted_tags: selectedTags,
    };

    this.steps.forEach(step => {
      if (step.type === "settings" && step.fields) {
        step.fields.forEach(field => {
          userData[field.id] = $(`#${field.id}`).prop("checked") as boolean;
        });
      }
    });

    return $.ajax({
      type: "PATCH",
      url: `/users/${this.userId}.json`,
      contentType: "application/json",
      data: JSON.stringify({ user: userData }),
    }).fail(err => {
      E621.Toast.error("Failed to update settings. Please try again later.");
    });
  }

  private completeOnboarding() {
    this.updateSettings().then(() => {
      $.ajax({
        type: "POST",
        url: "/onboarding/complete.json",
        contentType: "application/json",
        dataType: "json",
        data: JSON.stringify({}),
      })
        .done((data: OnboardingCompleteResponse) => {
          window.location.href = data.redirect_url || "/posts";
        })
        .fail((xhr, status, error) => {
          E621.Toast.error("Failed to complete onboarding. Please try again later.");
          window.location.href = "/posts";
        });
    });
  }

  private renderSteps() {
    const content = $(".onboarding-content");
    content.empty();

    this.steps.forEach((step, index) => {
      const stepEl = this.renderStep(step, index);
      content.append(stepEl);
    });
  }

  private renderStep(step: OnboardingStep, index: number): JQuery<HTMLElement> {
    const stepEl = $(`<div class="onboarding-step" id="step-${index}"></div>`);
    const title = $(`<h2>${step.title}</h2>`);
    stepEl.append(title);

    if (step.description) {
      const desc = $(`<p>${step.description}</p>`);
      stepEl.append(desc);
    }

    switch (step.type) {
      case "blacklist":
        this.renderBlacklistStep(stepEl, step);
        break;
      case "settings":
        this.renderSettingsStep(stepEl, step);
        break;
      case "info":
        this.renderInfoStep(stepEl, step);
        break;
    }

    return stepEl;
  }

  private renderBlacklistStep(stepEl: JQuery<HTMLElement>, step: OnboardingStep): void {
    const container = $(`<div class="common-blacklist-tags"></div>`);

    step.options?.forEach(tag => {
      const isChecked = step.current_value && step.current_value.includes(tag);
      const checked = isChecked ? "checked" : "";
      const tagEl = $(`
        <div class="tag-option">
          <input type="checkbox" 
                id="tag-${tag}" 
                class="blacklist-checkbox" 
                value="${tag}"
                ${checked}>
          <label for="tag-${tag}">${tag}</label>
        </div>
      `);
      container.append(tagEl);
    });

    stepEl.append(container);
  }

  private renderSettingsStep(stepEl: JQuery<HTMLElement>, step: OnboardingStep): void {
    step.fields?.forEach(field => {
      const isChecked = field.current_value ? "checked" : "";
      const fieldEl = $(`
        <div class="settings-option">
          <label>
            <input type="checkbox" id="${field.id}" ${isChecked}>
            <strong>${field.label}</strong>
          </label>
          <p class="help-text">${field.help_text}</p>
        </div>
      `);
      stepEl.append(fieldEl);
    });
  }

  private renderInfoStep(stepEl: JQuery<HTMLElement>, step: OnboardingStep): void {
    if (step.links && step.links.length > 0) {
      const notice = $(`<div class="notice notice-info"></div>`);
      const linksContainer = $(`<div style="display: flex; gap: 10px;"></div>`);
      step.links.forEach(link => {
        const linkEl = $("<a class='st-button'>")
          .attr("href", link.href)
          .text(link.label);
        linksContainer.append(linkEl);
      });
      notice.append(linksContainer);
      stepEl.append(notice);
    }
  }

  private showStep(step: number):void {
    $(".onboarding-step").each((i, el) => {
      $(el).toggle(i === step);
    });
    const totalSteps = this.steps.length;
    $("#step-counter").text(`Step ${step + 1} of ${totalSteps}`);
    $("#btn-prev").toggle(step > 0);
    $("#btn-next").toggle(step < totalSteps - 1);
    $("#btn-skip-all").toggle(step < totalSteps - 1);
    $("#btn-complete").toggle(step === totalSteps - 1);
  }
}

$(() => {
  if(!Page.matches("onboardings", "show")) return;

  const element = document.getElementById("onboarding-root");
  if (element) {
    new Onboarding(element);
  }
});