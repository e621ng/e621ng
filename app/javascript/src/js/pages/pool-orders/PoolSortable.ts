import Sortable from "@/utility/sortable";

$(() => {
  const orderForm = $("#ordering-form"),
    idInput = $("#pool_post_ids_string");
  const originalIDs = idInput.val();

  new Sortable($("ul.sortable"), { handleSelector: ".sortable-handle", onReorder: (orderedIDs: string[]) => {
    const idString = orderedIDs.join(" ");
    idInput.val(idString);

    orderForm.toggleClass("changed", idString !== originalIDs);
  }});
});
