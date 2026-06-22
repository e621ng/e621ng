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

$(() => {
  bootstrapReferencesEdit();
});
