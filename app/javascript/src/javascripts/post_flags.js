const PostFlags = {};


PostFlags.init = function () {
  if (PostFlags._initialized) {
    return;
  }
  PostFlags._initialized = true;

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

  function updateNoteRequired () {
    if (!noteField) return;
    const selected = document.querySelector("input[name=\"post_flag[reason_name]\"]:checked");
    const label = noteField.closest(".flag-notes")?.querySelector("label");
    if (selected && (selected.dataset.requireExplanation || "").trim().toLowerCase() === "true") {
      noteField.required = true;
      if (label) {
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
  }

  function showError (msg) {
    if (!noteField) return;
    if (!errorMessage) {
      errorMessage = document.createElement("div");
      errorMessage.className = "flag-note-error error-text";
      noteField.closest(".flag-notes")?.appendChild(errorMessage);
    }
    errorMessage.textContent = msg;
  }

  function clearError () {
    if (errorMessage) errorMessage.textContent = "";
  }

  function isNoteRequiredAndEmpty () {
    if (!noteField) return false;
    const selected = document.querySelector("input[name=\"post_flag[reason_name]\"]:checked");
    return selected && (selected.dataset.requireExplanation || "").trim().toLowerCase() === "true" && noteField.value.trim() === "";
  }

  if (form) {
    form.addEventListener("submit", function (e) {
      updateNoteRequired();
      if (isNoteRequiredAndEmpty()) {
        e.preventDefault();
        showError("Note is required for the selected reason.");
        if (noteField) noteField.focus();
      } else {
        clearError();
        if (e.submitter) {
          e.submitter.disabled = true;
        }
      }
    });
  }

  // Delegate change events from the container so switching selections always updates state
  const flagReasonContainer = document.querySelector(".flag-reason");
  if (flagReasonContainer) {
    flagReasonContainer.addEventListener("change", (e) => {
      if (!e.target || e.target.name !== "post_flag[reason_name]") return;
      // Remove selected class from all labels and add to the one containing the checked radio
      flagReasonLabels.forEach(l => l.classList.remove("selected"));
      const parentLabel = e.target.closest(".flag-reason-label");
      if (parentLabel) parentLabel.classList.add("selected");
      updateNoteRequired();
    });
    // Also ensure individual radios still trigger update on change
    Array.from(radioButtons).forEach(radio => {
      radio.addEventListener("change", updateNoteRequired);
    });
  }

  // Run on page load in case a reason is preselected
  updateNoteRequired();
};

export default PostFlags;

$(() => {
  PostFlags.init();
});

