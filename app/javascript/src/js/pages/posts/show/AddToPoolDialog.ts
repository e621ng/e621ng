import E621Type from "@/interfaces/E621";
import Dialog from "@/utility/dialog";

declare const E621: E621Type;

$(() => {
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
      E621.Toast.alert(`Error: ${data.status == 404 ? "Not Found" : data.responseText}`);
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
});
