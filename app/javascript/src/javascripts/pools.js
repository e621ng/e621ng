require("jquery-ui/ui/widgets/sortable");
require("jquery-ui/themes/base/sortable.css");
import Utility from './utility';

let Pool = {};

Pool.dialog_setup = false;

Pool.initialize_all = function() {
  if($("#c-pool-import").length) {
    this.initialize_import();
  }

  if ($("#c-posts").length && $("#a-show").length) {
    this.initialize_add_to_pool_link();
  }

  if ($("#c-pool-orders,#c-favorite-group-orders").length) {
    this.initialize_simple_edit();
  }
};

Pool.initialize_import = function() {
  $('#pool-import-preview-button').on('click', function(e) {
    Pool.import_preview(e);
  });
};

Pool.import_preview = function(e) {
  const tags = $('#pool-import-tags-field').val();
  const pool_id = $(e.target).data('pid');
  $.ajax({
    type: 'get',
    url: `/pools/${pool_id}/import_preview.json`,
    data: {tags: tags},
    dataType: 'json'
  }).done(function(data) {
    const posts = data.posts.map(p => `<li class="ui-state-default" id="import[post_ids]_${p.id}">${p.html}</li>`);
    $("#sortable-posts").html(posts.join(''));
    if ($("#sortable-posts.ui-sortable").length)
      $("#sortable-posts").sortable("destroy");
    $("#sortable-posts").sortable({
      placeholeder: "ui-state-placeholder"
    });
    $("#sortable-posts").disableSelection();

    $("#importing-form").off("submit").submit(function (e) {
      e.preventDefault();
      $.ajax({
        type: "post",
        url: e.target.action,
        data: $("#sortable-posts").sortable("serialize") + "&" + $(e.target).serialize()
      }).done(function() {
        window.location.assign("");
      });
    })
  }).fail(function(data) {
    Utility.error("Failed to get posts for import.");
  });
}

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

Pool.initialize_simple_edit = function() {
  $("#sortable").sortable({
    placeholder: "ui-state-placeholder"
  });
  $("#sortable").disableSelection();

  $("#ordering-form").submit(function(e) {
    $.ajax({
      type: "put",
      url: e.target.action,
      data: $("#sortable").sortable("serialize") + "&" + $(e.target).serialize()
    });
    e.preventDefault();
  });
}

$(document).ready(function() {
  Pool.initialize_all();
});

export default Pool
