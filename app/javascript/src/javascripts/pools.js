import Utility from "./utility";
import Sortable from "sortablejs";

let Pool = {};

Pool.dialog_setup = false;

Pool.initialize_all = function() {
  if ($("#c-posts").length && $("#a-show").length) {
    this.initialize_add_to_pool_link();
  }

  if ($("#c-pool-orders").length) {
    this.initialize_sortable_edit();
  }
};

Pool.initialize_add_to_pool_link = function() {
  $("#pool").on("click.danbooru", function(e) {
    if (!Pool.dialog_setup) {
      $("#add-to-pool-dialog").dialog({autoOpen: false});
      Pool.dialog_setup = true;
    }
    e.preventDefault();
    $("#add-to-pool-dialog").dialog("open");
  });

  $("#recent-pools li").on("click.danbooru", function(e) {
    e.preventDefault();
    $("#pool_name").val($(this).attr("data-value"));
  });
}

Pool.initialize_sortable_edit = function() {
  const sortable = Sortable.create($("#pool-sortable")[0]);
  $("#pool-sortable-submit").on("click", e => {
    e.preventDefault();
    const path = e.target.getAttribute("data-target");
    $.ajax({
      type: "put",
      url: path,
      data: {
        pool: {
          post_ids: sortable.toArray(),
        }
      },
      dataType: "json",
      success: () => {
        location.href = path;
      },
      error: () => {
        Utility.error("Failed to save pool order.");
      }
    });
  });
}

$(() => {
  Pool.initialize_all();
});

export default Pool
