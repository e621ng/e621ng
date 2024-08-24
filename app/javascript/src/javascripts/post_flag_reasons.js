import Utility from "./utility";

class PostFlagReasons {
  static initialize_listeners () {
    const $editOrderLink = $(".edit-order-link");
    const $saveOrderLink = $(".save-order-link");
    const $sortableReasons = $("#sortable-reasons");

    $editOrderLink.on("click.e621.sorting", function (event) {
      event.preventDefault();
      $saveOrderLink.show();
      $editOrderLink.hide();
      $sortableReasons.sortable({
        items: "tbody tr",
      });
      Utility.notice("Drag and drop to reorder.");
    });

    $saveOrderLink.on("click.e621.sorting", function (event) {
      event.preventDefault();
      $saveOrderLink.hide();
      $.ajax({
        url: "/post_flag_reasons/reorder.js",
        type: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        data: PostFlagReasons.reorder_data(),
        dataType: "json",
        success (data) {
          $("#sortable-rules-container").html(data.html);
          Utility.notice("Order updated.");
          $editOrderLink.show();
          PostFlagReasons.reinitialize_listeners();
        },
        error (data) {
          if (data.responseJSON.message) {
            Utility.error(`Failed to update order: ${data.responseJSON.message}`);
          } else if (data.responseJSON.errors) {
            Utility.error(`Failed to update order:<br>${data.responseJSON.errors.map(e => `${e.name}: ${e.message}`).join("<br>")}`);
          } else {
            Utility.error("Failed to update order.");
          }
          $saveOrderLink.show();
          $sortableReasons.sortable({
            items: "tbody tr",
          });
        },
      });
    });
  }

  static reinitialize_listeners () {
    $(".edit-order-link").off("click.e621.sorting");
    $(".save-order-link").off("click.e621.sorting");
    this.initialize_listeners();
  }

  static reorder_data () {
    const data = [];
    Array.from($("#sortable-reasons tbody tr")).forEach((category, index) => {
      data.push({
        id: Number(category.dataset.reasonId),
        order: index + 1,
      });
    });
    return JSON.stringify(data);
  }
}

$(document).ready(function () {
  if ($("#c-post-flag-reasons #a-order").length) {
    PostFlagReasons.initialize_listeners();
  }
});

export default PostFlagReasons;
