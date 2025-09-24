import Page from "./utility/page";

const PostFlags = {};

// Note sections are transformed into expandable containers if they exceed a certain height
PostFlags.initExpandableNotes = function () {
  for (const container of $(".post-flag-note")) {
    if (container.clientHeight > 72) $(container).addClass("expandable");
  }

  $(".post-flag-note-header").on("click", (event) => {
    $(event.currentTarget).parents(".post-flag-note").toggleClass("expanded");
  });
};


PostFlags.initFlagForm = function () {
  // Form should always be present
  const form = $("#new_post_flag");
  if (form.length === 0) return;

  // Label the note field as required if the selected reason requires an explanation
  const noteLabel = form.find("label[for='flag_note_field']");
  $("<span>")
    .addClass("required-indicator")
    .text(" (required)")
    .appendTo(noteLabel);
  form.on("change", "input[type='radio']", updateNoteRequired);

  let isNoteRequired = false;
  function updateNoteRequired () {
    const selected = form.find("input[name='post_flag[reason_name]']:checked");
    isNoteRequired = selected.data("requireExplanation") === true;
    noteLabel.toggleClass("required", isNoteRequired);
    toggleSubmitButton();
  }


  // Determine if the note field is empty dynamically
  let isNoteEmpty = false;
  const noteField = form.find("#flag_note_field").on("input", () => {
    isNoteEmpty = (noteField.val() || "").trim() === "";
    toggleSubmitButton();
  });


  // Toggle the submit button based on whether the note is required and empty
  const submitButton = form.find("input[type='submit']");
  function toggleSubmitButton () {
    submitButton.attr("disabled", isNoteRequired && isNoteEmpty ? "disabled" : null);
  }


  // Extra validation on submit
  const noteHint = form.find(".flag-note-hint");
  form.on("submit", (event) => {
    noteHint.hide();
    if (!isNoteRequired || !isNoteEmpty) return true;

    event.preventDefault();
    noteHint.show();
    return false;
  });


  // Initial state
  isNoteRequired = form.find("input[name='post_flag[reason_name]']:checked").data("requireExplanation") === true;
  isNoteEmpty = (noteField.val() || "").trim() === "";
  noteLabel.toggleClass("required", isNoteRequired);
  toggleSubmitButton();
};

$(() => {
  PostFlags.initExpandableNotes();
  if (Page.matches("post-flags", "new"))
    PostFlags.initFlagForm();
});

export default PostFlags;
