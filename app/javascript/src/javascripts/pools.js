import Utility from "./utility";

let Pool = {};

Pool.dialog_setup = false;

Pool.initialize_all = function () {
  if ($("#c-posts").length && $("#a-show").length) {
    this.initialize_add_to_pool_link();
  }

  if ($("#c-pool-orders").length) {
    this.initialize_simple_edit();
  }
};

Pool.initialize_add_to_pool_link = function () {
  $("#pool").on("click.danbooru", function (e) {
    if (!Pool.dialog_setup) {
      $("#add-to-pool-dialog").dialog({autoOpen: false});
      Pool.dialog_setup = true;
    }
    e.preventDefault();
    $("#add-to-pool-dialog").dialog("open");
  });

  $("#recent-pools li").on("click.danbooru", function (e) {
    e.preventDefault();
    $("#pool_name").val($(this).attr("data-value"));
  });
};

Pool.initialize_simple_edit = function () {
  $("#sortable").sortable({
    placeholder: "ui-state-placeholder",
  });
  $("#sortable").disableSelection();

  $("#ordering-form").submit(function (e) {
    e.preventDefault();
    $.ajax({
      type: "post",
      url: e.target.action,
      data: $("#sortable").sortable("serialize") + "&" + $(e.target).serialize() + "&format=json",
    }).done(() => {
      window.location.href = e.target.action;
    }).fail((data) => {
      Utility.error(`Error: ${data.responseText}`);
    });
  });
};

$(document).ready(function () {
  Pool.initialize_all();
});

export default Pool;
