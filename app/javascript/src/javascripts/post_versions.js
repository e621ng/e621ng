import Utility from './utility';
import {SendQueue} from "./send_queue";

let PostVersion = {};

PostVersion.updated = 0;
PostVersion.initialize_all = function () {
  if ($("#c-post-versions #a-index").length) {
    PostVersion.initialize_undo();
  }
};

PostVersion.initialize_undo = function () {
  /* Expand the clickable area of the checkbox to the entire table cell. */
  $(".post-version-row-select").on("click.danbooru", function (event) {
    $(event.target).find(".post-version-select:not(:disabled)").prop("checked", (_, checked) => !checked).change();
  });

  $("#post-version-select-all").on("change.danbooru", function (event) {
    $("td .post-version-select:not(:disabled)").prop("checked", $("#post-version-select-all").prop("checked")).change();
  });

  $(".post-version-select").on("change.danbooru", function (event) {
    let checked = $("td .post-version-select:checked");
    $("#subnav-undo-selected-link").text(`Undo selected (${checked.length})`).toggle(checked.length > 0);
  });

  $("#subnav-undo-selected-link").on("click.danbooru", PostVersion.undo_selected);
};

PostVersion.undo_selected = function () {
  event.preventDefault();

  PostVersion.updated = 0;
  let selected_rows = $("td .post-version-select:checked").parents("tr");

  for (let row of selected_rows) {
    let id = $(row).data("post-version-id");

    SendQueue.add(function () {
      $.ajax(`/post_versions/${id}/undo.json`, {method: "PUT"});

      Utility.notice(`${++PostVersion.updated}/${selected_rows.length} changes undone.`);
    });
  }
};

$(document).ready(PostVersion.initialize_all);
export default PostVersion;
