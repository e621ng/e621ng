import Dialog from "./utility/dialog";
import Page from "./utility/page";
import Sortable from "./utility/sortable";

let Pool = {};

Pool.initialize_all = function () {
  if ($("#c-posts").length && $("#a-show").length) {
    this.initialize_add_to_pool_link();
  }
};

Pool.initialize_add_to_pool_link = function () {
  let poolDialog = null;
  $(".add-to-pool").on("click.danbooru", function (event) {
    event.preventDefault();

    if (!poolDialog)
      poolDialog = new Dialog("#add-to-pool-dialog");
    poolDialog.toggle();
  });

  $("#recent-pools li").on("click.danbooru", function (e) {
    e.preventDefault();
    $("#pool_name").val($(this).attr("data-value"));
  });
};

Pool.initialize_pool_ordering = function () {
  if (!Page.matches("pool-orders", "edit")) return;

  const orderForm = $("#ordering-form"),
    idInput = $("#pool_post_ids_string");
  const originalIDs = idInput.val();

  new Sortable($("ul.sortable"), { onReorder: (orderedIDs) => {
    const idString = orderedIDs.join(" ");
    idInput.val(idString);

    orderForm.toggleClass("changed", idString !== originalIDs);
  }});
};

$(() => {
  Pool.initialize_all();
  Pool.initialize_pool_ordering();
});

export default Pool;
