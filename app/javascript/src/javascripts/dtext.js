let Dtext = {};

Dtext.initialize_all = function() {
  Dtext.initialize_links();
  Dtext.initialize_expandables();
}

Dtext.initialize_links = function() {
  $(document).on("click.danbooru", ".dtext-preview-button", Dtext.click_button);
}

Dtext.initialize_expandables = function() {
  $(document).on("click.danbooru", ".expandable-header", function(e) {
    const header = $(this);
    header.next().fadeToggle("fast");
    header.parent().toggleClass("expanded");
  });
};

Dtext.call_preview = function(e, $button, $input, $preview) {
  $button.val("Edit");
  $input.hide();
  $preview.text("Loading...").fadeIn("fast");
  $.ajax({
    type: "post",
    url: "/dtext_preview",
    dataType: "json",
    data: {
      body: $input.val()
    },
    success: function(data) {
      $preview.html(data.html).fadeIn("fast");
      $(window).trigger('e621:add_deferred_posts', data.posts);
    }
  });
}

Dtext.call_edit = function(e, $button, $input, $preview) {
  $button.val("Preview");
  $preview.hide();
  $input.slideDown("fast");
}

Dtext.click_button = function(e) {
  var $button = $(e.target);
  var $input = $("#" + $button.data("input-id"));
  var $preview = $("#" + $button.data("preview-id"));

  if ($button.val().match(/preview/i)) {
    Dtext.call_preview(e, $button, $input, $preview);
  } else {
    Dtext.call_edit(e, $button, $input, $preview);
  }

  e.preventDefault();
}

$(document).ready(function() {
  Dtext.initialize_all();
});

export default Dtext
