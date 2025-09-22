const PostFlags = {};


PostFlags.init = function () {
  if (PostFlags._initialized) {
    console.debug("PostFlags.init: already initialized");
    return;
  }
  PostFlags._initialized = true;
  console.debug("PostFlags.init: initializing");
  for (const container of $(".post-flag-note")) {
    if (container.clientHeight > 72) $(container).addClass("expandable");
  }

  $(".post-flag-note-header").on("click", (event) => {
    $(event.currentTarget).parents(".post-flag-note").toggleClass("expanded");
  });


  const flagReasonLabels = document.querySelectorAll(".flag-reason-label");
  const noteField = document.getElementById("flag_note_field");
  // Use a live collection so newly-checked inputs are reflected
  const radioButtons = document.getElementsByName("post_flag[reason_name]");
  // Find the form by traversing up from the note field, or fallback to the first form in the flag-dialog-body
  let form = null;
  if (noteField) {
    form = noteField.closest("form");
  } else {
    const dialogBody = document.querySelector(".flag-dialog-body");
    if (dialogBody) {
      form = dialogBody.querySelector("form");
    }
  }
  let errorMessage = null;

  // Parse dataset boolean values robustly. Treat presence or values like "", "true", "1", "yes" as true.
  function parseDatasetBoolean (val) {
    if (val === undefined || val === null) return false;
    const v = String(val).trim().toLowerCase();
    if (v === "" || v === "true" || v === "1" || v === "yes") return true;
    return false;
  }

  function updateNoteRequired () {
    try {
      if (!noteField) return;
      const selected = document.querySelector("input[name=\"post_flag[reason_name]\"]:checked");
      const label = noteField.closest(".flag-notes")?.querySelector("label");
      if (selected && parseDatasetBoolean(selected.dataset.requireExplanation)) {
        noteField.required = true;
        if (label) {
          // Add a small indicator span instead of replacing the label content
          let indicator = label.querySelector(".required-indicator");
          if (!indicator) {
            indicator = document.createElement("span");
            indicator.className = "required-indicator";
            indicator.textContent = " (required)";
            label.appendChild(indicator);
          }
        }
      } else {
        noteField.required = false;
        if (label) {
          const indicator = label.querySelector(".required-indicator");
          if (indicator) indicator.remove();
        }
      }
    } catch (err) {
      console.error("PostFlags.updateNoteRequired error", err);
    }
  }

  function showError (msg) {
    try {
      if (!noteField) return;
      if (!errorMessage) {
        errorMessage = document.createElement("div");
        errorMessage.className = "flag-note-error error-text";
        noteField.closest(".flag-notes")?.appendChild(errorMessage);
      }
      errorMessage.textContent = msg;
    } catch (err) {
      console.error("PostFlags.showError error", err);
    }
  }

  function clearError () {
    if (errorMessage) errorMessage.textContent = "";
  }

  function isNoteRequiredAndEmpty () {
    try {
      if (!noteField) return false;
      const selected = document.querySelector("input[name=\"post_flag[reason_name]\"]:checked");
      return selected && parseDatasetBoolean(selected.dataset.requireExplanation) && noteField.value.trim() === "";
    } catch (err) {
      console.error("PostFlags.isNoteRequiredAndEmpty error", err);
      return false;
    }
  }

  if (form) {
    console.debug("PostFlags: attaching submit handler to form", form);
    form.addEventListener("submit", function (e) {
      try {
        updateNoteRequired();
        if (isNoteRequiredAndEmpty()) {
          e.preventDefault();
          showError("Note is required for the selected reason.");
          if (noteField) noteField.focus();
        } else {
          clearError();
        }
      } catch (err) {
        console.error("PostFlags: submit handler error", err);
      }
    });
  } else {
    console.debug("PostFlags: form not found; submit handler not attached");
  }

  // Delegate change events from the container so switching selections always updates state
  const flagReasonContainer = document.querySelector(".flag-reason");
  if (flagReasonContainer) {
    flagReasonContainer.addEventListener("change", (e) => {
      try {
        if (!e.target || e.target.name !== "post_flag[reason_name]") return;
        // Remove selected class from all labels and add to the one containing the checked radio
        flagReasonLabels.forEach(l => l.classList.remove("selected"));
        const parentLabel = e.target.closest(".flag-reason-label");
        if (parentLabel) parentLabel.classList.add("selected");
        updateNoteRequired();
      } catch (err) {
        console.error("PostFlags: flagReasonContainer change handler error", err);
      }
    });
    // Also ensure individual radios still trigger update on change
    Array.from(radioButtons).forEach(radio => {
      radio.addEventListener("change", updateNoteRequired);
    });
  } else {
    // Fallback: attach listeners directly if container not present
    if (radioButtons && radioButtons.length) {
      for (let i = 0; i < radioButtons.length; i++) {
        radioButtons[i].addEventListener("change", updateNoteRequired);
      }
    } else {
      console.debug("PostFlags: no radio buttons found for reason_name");
    }
    if (flagReasonLabels && flagReasonLabels.length) {
      flagReasonLabels.forEach(label => {
        label.addEventListener("click", () => {
          flagReasonLabels.forEach(l => l.classList.remove("selected"));
          label.classList.add("selected");
        });
      });
    }
  }

  // Run on page load in case a reason is preselected
  updateNoteRequired();
};

export default PostFlags;

// Auto-initialize on standard DOM load
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => PostFlags.init());
} else {
  // Document already loaded
  PostFlags.init();
}

// Support Turbo (Rails 7) or Turbolinks navigation
document.addEventListener("turbo:load", () => PostFlags.init());
document.addEventListener("turbolinks:load", () => PostFlags.init());
