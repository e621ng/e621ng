import Page from "./utility/page";

const PostReports = {};

// Note sections are transformed into expandable containers if they exceed a certain height
PostReports.initExpandableNotes = function () {
  for (const container of $(".post-flag-note")) {
    if (container.clientHeight > 72) $(container).addClass("expandable");
  }

  $(".post-flag-note-header").on("click", (event) => {
    $(event.currentTarget).parents(".post-flag-note").toggleClass("expanded");
  });
};


PostReports.initFlagForm = function () {
  // Form should always be present
  const form = $("#post-report-form");
  if (form.length === 0) return;

  // Label the note field as required if the selected reason requires an explanation
  const noteLabel = form.find("label[for='report_note_field']");
  $("<span>")
    .addClass("required-indicator")
    .text(" (required)")
    .appendTo(noteLabel);
  form.on("change", "input[type='radio']", onReasonRadioChange);

  function onReasonRadioChange (event) {
    console.log("target", event.target);
    updateNoteRequired();
    displayNoteChildren(event.target);
  }

  //   Set whether the note field is required
  let isNoteRequired = false;
  function updateNoteRequired () {
    const selected = form.find("input[name='reason_name']:checked");
    isNoteRequired = selected.data("needsExplanation") === true;
    noteLabel.toggleClass("required", isNoteRequired);
    toggleSubmitButton();
  }

  function displayNoteChildren (element) {
    const selector = $(element);

    // Show/hide children
    $(".report-reason-children").hide();
    $(".report-reason-children[data-parent-id='" + selector.data("id") + "']").show();
    const parentString = selector.data("parents") + "";
    console.log("parentString", parentString);
    if (!parentString) return;
    const parentIds = parentString.split(" ").map((x) => x.trim());
    console.log("parentIds", parentIds);
    for (const id of parentIds) {
      $(".report-reason-children[data-parent-id='" + id + "']").show();
    }
  }


  // Determine if the note field is empty dynamically
  let isNoteEmpty = false;
  const noteField = form.find("#report_note_field").on("input", () => {
    isNoteEmpty = (noteField.val() || "").trim() === "";
    toggleSubmitButton();
  });


  // Toggle the submit button based on whether the note is required and empty
  const submitButton = form.find("input[type='submit']");
  function toggleSubmitButton () {
    submitButton.attr("disabled", isNoteRequired && isNoteEmpty ? "disabled" : null);
  }


  // Extra validation on submit
  const noteHint = form.find(".report-note-hint");
  form.on("submit", (event) => {
    noteHint.hide();
    if (!isNoteRequired || !isNoteEmpty) return true;

    event.preventDefault();
    noteHint.show();
    return false;
  });


  // Initial state
  const selected = form.find("input[name='reason_name']:checked");
  if (selected.length > 0) {
    displayNoteChildren(selected[0]);
    isNoteRequired = selected.data("needsExplanation") === true;
  }
  isNoteEmpty = (noteField.val() || "").trim() === "";
  noteLabel.toggleClass("required", isNoteRequired);
  toggleSubmitButton();
};

$(() => {
  PostReports.initExpandableNotes();
  if (Page.matches("posts", "report"))
    PostReports.initFlagForm();
});

export default PostReports;
