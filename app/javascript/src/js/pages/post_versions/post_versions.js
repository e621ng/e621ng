import Post from "@/pages/posts/posts";
import TaskQueue from "@/utility/TaskQueue";

let PostVersion = {};

PostVersion.updated = 0;
PostVersion.initialize_all = function () {
  if (!$("#c-post-versions #a-index").length) return;

  PostVersion.init_undo_selected();
  $("#subnav-apply-tag-script-to-selected-link").on("click", PostVersion.tag_script_selected);
};

PostVersion.init_undo_selected = function () {
  if (!$("body").data("userIsPrivileged")) return;

  // "Select All" and "Undo Selected" buttons
  $("#subnav-select-all-link").on("click.danbooru", (event) => {
    event.preventDefault();
    $(".post-version-select:not(:disabled)").prop("checked", true).trigger("change");
  });
  $("#subnav-undo-selected-link").on("click.danbooru", PostVersion.undo_selected);

  // Expand the clickable area of the checkbox to the entire table cell
  $(".post-version-row-select").on("click.danbooru", (event) => {
    $(event.target).find(".post-version-select:not(:disabled)").prop("checked", (_, checked) => !checked).trigger("change");
  });

  $(".post-version-select").on("change.danbooru", () => {
    let checked = $(".post-version-select:checked");
    $("#subnav-undo-selected-link").text(`Undo selected (${checked.length})`).toggle(checked.length > 0);
  });
};

PostVersion.undo_selected = function (event) {
  event.preventDefault();

  PostVersion.updated = 0;
  let selected_rows = $(".post-version-select:checked").parents(".post-version");

  const toast = E621.Toast.create("Undoing changes...", { timeout: 0 });
  const promises = [];
  for (let row of selected_rows) {
    let id = $(row).data("post-version-id");

    promises.push(TaskQueue.add(() => {
      $.ajax(`/post_versions/${id}/undo.json`, {method: "PUT"});

      toast.message = `${++PostVersion.updated} / ${selected_rows.length} changes undone.`;
    }, { name: "PostVersion.undo_selected" }));
  }

  Promise.all(promises).then(() => {
    toast.message = `Successfully undone ${PostVersion.updated} change${PostVersion.updated !== 1 ? "s" : ""}.`;
    toast.timeout = 3;
  }).catch(e => {
    toast.dismiss(true);
    E621.Toast.alert("Failed to undo selected changes: " + (e.message || e.statusText || "unknown error"));
  });
};

PostVersion.tag_script_selected = function (event) {
  event.preventDefault();

  PostVersion.updated = 0;
  let selected_rows = $(".post-version-select:checked").parents(".post-version");
  const script = $("#update-tag-script").val();
  if (!script)
    return;

  const toast = E621.Toast.create("Applying tag script...", { timeout: 0 });
  const promises = [];
  for (let row of selected_rows) {
    let id = $(row).data("post-id");

    promises.push(TaskQueue.add(() => {
      Post.tagScript(id, script);

      toast.message = `${++PostVersion.updated} / ${selected_rows.length} changes applied.`;
    }, { name: "PostVersion.tag_script_selected" }));
  }
  Promise.all(promises).then(() => {
    toast.message = `Successfully applied ${PostVersion.updated} change${PostVersion.updated !== 1 ? "s" : ""}.`;
    toast.timeout = 3;
  }).catch(e => {
    toast.dismiss(true);
    E621.Toast.alert("Failed to apply tag script to selected changes: " + (e.message || e.statusText || "unknown error"));
  });
};

$(() => PostVersion.initialize_all());

export default PostVersion;
