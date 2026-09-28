import ToastManager from "@/utility/Toast";
import Dialog from "@/utility/dialog";

$(() => {
  const trigger = $("#favorite-folder-new-trigger");
  const dialogEl = $("#favorite-folder-dialog");
  if (trigger.length === 0 || dialogEl.length === 0) return; // not on a folder-scoped Favorites page

  let folderDialog: Dialog | null = null;

  function openDialog (title: string, folderId: string, name: string) {
    if (!folderDialog) folderDialog = new Dialog("#favorite-folder-dialog");
    $("#favorite-folder-id").val(folderId);
    $("#favorite-folder-name").val(name);
    folderDialog.setTitle(title);
    folderDialog.toggle();
  }

  trigger.on("click.danbooru", (event) => {
    event.preventDefault();
    openDialog("New Folder", "", "");
  });

  // Delegated: rename triggers live inside FolderCardComponent, one per card.
  $(document).on("click.danbooru", ".favorite-folder-rename-trigger", (event) => {
    event.preventDefault();
    const el = $(event.currentTarget);
    openDialog("Rename Folder", String(el.data("folder-id")), String(el.data("folder-name")));
  });

  dialogEl.on("submit", (event) => {
    event.preventDefault();

    const folderId = $("#favorite-folder-id").val() as string;
    const name = $("#favorite-folder-name").val() as string;
    const parentId = $("#favorite-folder-parent-id").val() as string;
    const isRename = !!folderId;

    $.ajax({
      type: isRename ? "PATCH" : "POST",
      url: isRename ? `/favorite_folders/${folderId}.json` : "/favorite_folders.json",
      data: { name, parent_id: parentId || undefined },
    }).done(() => {
      window.location.reload();
    }).fail((response) => {
      ToastManager.alert(`Error: ${response.responseJSON?.message || response.statusText}`);
    });

    return false;
  });
});
