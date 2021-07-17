import Utility from './utility';
import {SendQueue} from "./send_queue";
import Post from './posts';

let PostVersion = {};

PostVersion.updated = 0;
PostVersion.initialize_all = function () {
  if ($("#c-post-versions #a-index").length) {
    PostVersion.initialize_undo();
    $('#subnav-select-all-link').on('click', function(event) {
      event.preventDefault();
      $(".post-version-select:not(:disabled)").prop("checked", true).change();
    });
    $("#subnav-apply-tag-script-to-selected-link").on('click', PostVersion.tag_script_selected);
  }
};

PostVersion.initialize_undo = function () {
  /* Expand the clickable area of the checkbox to the entire table cell. */
  $(".post-version-row-select").on("click.danbooru", function (event) {
    $(event.target).find(".post-version-select:not(:disabled)").prop("checked", (_, checked) => !checked).change();
  });

  $("#post-version-select-all").on("change.danbooru", function (event) {
    $(".post-version-select:not(:disabled)").prop("checked", $("#post-version-select-all").prop("checked")).change();
  });

  $(".post-version-select").on("change.danbooru", function (event) {
    let checked = $(".post-version-select:checked");
    $("#subnav-undo-selected-link").text(`Undo selected (${checked.length})`).toggle(checked.length > 0);
  });

  $("#subnav-undo-selected-link").on("click.danbooru", PostVersion.undo_selected);
};

PostVersion.undo_selected = function () {
  event.preventDefault();

  PostVersion.updated = 0;
  let selected_rows = $(".post-version-select:checked").parents(".post-version");

  for (let row of selected_rows) {
    let id = $(row).data("post-version-id");

    SendQueue.add(function () {
      $.ajax(`/post_versions/${id}/undo.json`, {method: "PUT"});

      Utility.notice(`${++PostVersion.updated}/${selected_rows.length} changes undone.`);
    });
  }
};

PostVersion.tag_script_selected = function() {
  event.preventDefault();

  PostVersion.updated = 0;
  let selected_rows = $(".post-version-select:checked").parents(".post-version");
  const script = $("#update-tag-script").val();
  if(!script)
    return;

  for (let row of selected_rows) {
    let id = $(row).data("post-id");

    SendQueue.add(function () {
      Post.tagScript(id, script);

      Utility.notice(`${++PostVersion.updated}/${selected_rows.length} changes applied.`);
    });
  }
}

$(document).ready(PostVersion.initialize_all);
export default PostVersion;
