const StaffNote = {};

StaffNote.initialize_all = function () {
  $(".expand-new-staff-note").on("click", StaffNote.show_new_note_form);
  $(".edit-staff-note-link").on("click", StaffNote.show_edit_form);
};

StaffNote.show_new_note_form = function (e) {
  e.preventDefault();
  $(e.target).hide();
  var $form = $(e.target).closest("div.new-staff-note").find("form");
  $form.show();
  $form[0].scrollIntoView(false);
};

StaffNote.show_edit_form = function (e) {
  e.preventDefault();
  $(this).closest(".staff-note").find(".edit_staff_note").show();
};

$(document).ready(function () {
  StaffNote.initialize_all();
});

export default StaffNote;
