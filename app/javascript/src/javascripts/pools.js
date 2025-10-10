import Utility from "./utility";
import Dialog from "./utility/dialog";

let Pool = {};

Pool.initialize_all = function () {
  if ($("#c-posts").length && $("#a-show").length) {
    this.initialize_add_to_pool_link();
  }

  if ($("#c-pool-orders").length) {
    this.initialize_simple_edit();
  }
};

Pool.initialize_add_to_pool_link = function () {
  let poolDialog = null;
  $(".add-to-pool").on("click.danbooru", function (event) {
    event.preventDefault();

    if (!poolDialog) {
      poolDialog = new Dialog("#add-to-pool-dialog");
      loadRecentPools();
    }
    poolDialog.toggle();
  });

  $("#recent-pools").on("click.danbooru", "li", (event) => {
    event.preventDefault();
    $("#pool_name").val($(event.currentTarget).attr("data-value"));
  });

  // Form submission
  $("#add-to-pool-dialog").on("submit", handleAddToPool);
  function handleAddToPool (event) {
    event.preventDefault();
    const pool_name = $("#pool_name").val();
    const post_id = $("#post_id").val();

    $.ajax({
      type: "POST",
      url: "/pool_element",
      data: {
        pool_name: pool_name,
        post_id: post_id,
        format: "json",
      },
    }).done(() => {
      window.location.reload();
    }).fail((data) => {
      Utility.error(`Error: ${data.status == 404 ? "Not Found" : data.responseText}`);
    });

    return false;
  }

  // Load recent pools when the dialog is shown
  function loadRecentPools () {
    $.ajax({
      type: "GET",
      url: "/pool_element/recent",
      dataType: "json",
    }).done((data) => {
      const recentPoolsList = $("#recent-pools");
      if (data.length === 0) return;

      data.forEach((pool) => {
        recentPoolsList.append(`<li data-value="${pool.name}" role="button"><a href="/pools/${pool.id}">${pool.name}</a></li>`);
      });
      $(".add-to-pool-recent").show();
    });
  }
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
