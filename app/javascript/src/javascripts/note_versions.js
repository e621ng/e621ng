import { SendQueue } from "./send_queue";
import Utility from "./utility";
import PostVersion from "./post_versions";

const NoteVersion = {};

NoteVersion.updated = 0;
NoteVersion.initialize_all = function () {
  if (!$("#c-note-versions #a-index").length) return;

  NoteVersion.init_undo_selected();
};

NoteVersion.init_undo_selected = function () {
  if (!$("body").data("userIsPrivileged")) return;

  // "Select All" and "Undo Selected" buttons
  $("#subnav-select-all-link").on("click.danbooru", (event) => {
    event.preventDefault();
    $(".note-version-select:not(:disabled)").prop("checked", true).trigger("change");
  });
  $("#subnav-undo-selected-link").on("click.danbooru", NoteVersion.undo_selected);

  // Expand the clickable area of the checkbox to the entire table cell
  $(".post-version-row-select").on("click.danbooru", (event) => {
    $(event.target).find(".note-version-select:not(:disabled)").prop("checked", (_, checked) => !checked).trigger("change");
  });

  $(".post-version-select").on("change.danbooru", () => {
    let checked = $(".post-version-select:checked");
    $("#subnav-undo-selected-link").text(`Undo selected (${checked.length})`).toggle(checked.length > 0);
  });
};

NoteVersion.undo_selected = function (event) {
  event.preventDefault();

  NoteVersion.updated = 0;
  const selected_rows = $(".note-version-select:checked").parents(".note-version");

  for (const row of selected_rows) {
    const id = $(row).data("note-version-id");

    SendQueue.add(function () {
      $.ajax(`/note_versions/${id}/undo.json`, { method: "PUT" }).done(() => {
        Utility.notice(`${++NoteVersion.updated}/${selected_rows.length} changes undone.`);
      });
    });
  }
};

$(() => NoteVersion.initialize_all());

export default NoteVersion;
