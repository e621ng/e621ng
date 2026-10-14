import Dialog from "@/utility/dialog";

function bootstrapReferencesEdit () {
  const wrapper = document.getElementById("staff-wiki-references");
  if (!wrapper) return;

  const editButton = document.getElementById("staff-wiki-references-edit");
  if (!editButton) return;

  let isEditing = false;
  editButton.addEventListener("click", () => {
    isEditing = !isEditing;
    wrapper.setAttribute("data-editing", String(isEditing));
    editButton.textContent = isEditing ? "Done" : "Edit";
  });
}

function bootstrapBulkImport () {
  const bulkButton = document.getElementById("staff-wiki-references-bulk");
  if (!bulkButton) return;

  let dialog = null;
  bulkButton.addEventListener("click", () => {
    if (!dialog) dialog = new Dialog("#bulk-import-dialog");
    dialog.toggle();
  });
}

$(() => {
  bootstrapReferencesEdit();
  bootstrapBulkImport();
});
