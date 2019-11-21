import Post from './posts.js.erb'

let Upload = {};

Upload.initialize_all = function() {
  if ($("#c-uploads,#c-posts").length) {
    $("#upload_direct_url").on("change.danbooru", Upload.fetch_data_manual);
    $(document).on("click.danbooru", "#fetch-data-manual", Upload.fetch_data_manual);
  }

  if ($("#c-uploads").length) {
    if ($("#image").prop("complete")) {
      this.initialize_image();
    } else {
      $("#image").on("error.danbooru", (e) => {
        $("#upload-image").hide();
        $("#scale-link").hide();
        $("#iqdb-similar").hide();
      });
      $("#image").on("load.danbooru", this.initialize_image);
    }
    this.initialize_similar();
    this.initialize_submit();

    $("#toggle-artist-commentary").on("click.danbooru", function(e) {
      Upload.toggle_commentary();
      e.preventDefault();
    });
  }

  if ($("#iqdb-similar").length) {
    this.initialize_iqdb_source();
  }
}

Upload.initialize_submit = function() {
  $("#form").on("submit.danbooru", Upload.validate_upload);
}

Upload.validate_upload = function (e) {
  var error_messages = [];
  if (($("#upload_file").val() === "") && !/^https?:\/\//i.test($("#upload_direct_url").val()) && $("#upload_md5_confirmation").val() === "") {
    error_messages.push("Must choose file or specify source");
  }
  if (!$("#upload_rating_s").prop("checked") && !$("#upload_rating_q").prop("checked") && !$("#upload_rating_e").prop("checked") &&
      ($("#upload_tag_string").val().search(/\brating:[sqe]/i) < 0)) {
    error_messages.push("Must specify a rating");
  }
  if (error_messages.length === 0) {
    $("#submit-button").prop("disabled", "true");
    $("#submit-button").prop("value", "Submitting...");
    $("#client-errors").hide();
  } else {
    $("#client-errors").html("<strong>Error</strong>: " + error_messages.join(", "));
    $("#client-errors").show();
    e.preventDefault();
  }
}

Upload.initialize_iqdb_source = function() {
  if (/^https?:\/\//.test($("#upload_direct_url").val())) {
    $.get("/iqdb_queries", {"url": $("#upload_direct_url").val()}).done(function(html) {$("#iqdb-similar").html(html)});
  }
}

Upload.initialize_similar = function() {
  $("#similar-button").on("click.danbooru", function(e) {
    $.get("/iqdb_queries", {"url": $("#upload_direct_url").val()}).done(function(html) {$("#iqdb-similar").html(html).show()});
    e.preventDefault();
  });
}

Upload.update_scale = function() {
  var $image = $("#image");
  var ratio = $image.data("scale-factor");
  if (ratio < 1) {
    $("#scale").html("Scaled " + parseInt(100 * ratio) + "% (original: " + $image.data("original-width") + "x" + $image.data("original-height") + ")");
  } else {
    $("#scale").html("Original: " + $image.data("original-width") + "x" + $image.data("original-height"));
  }
}

Upload.showWhitelistWarning = function(allowed, reason, domain) {
  if (allowed) {
    $("#whitelist-warning").addClass("whitelist-warning-allowed").removeClass("whitelist-warning-disallowed");
    $("#whitelist-warning").html("Uploads from <span style='font-weight:bold'>" + domain + "</span> are permitted!");
  } else {
    $("#whitelist-warning").removeClass("whitelist-warning-allowed").addClass("whitelist-warning-disallowed");
    $("#whitelist-warning").html("Uploads from <span style='font-weight:bold'>" + domain + "</span> are not permitted: " + reason + " (<a href='/upload_whitelists'>View whitelisted domains</a>)");
  }
  $("#whitelist-warning").show();
}

Upload.fetch_data_manual = function(e) {
  var url = $("#upload_direct_url").val();
  var ref = $("#upload_referer_url").val();

  if(!url.length)
    $("#whitelist-warning").hide();

  if (/^https?:\/\//.test(url)) {
    $("#source-info").addClass("loading");
    $.get("/source.js", { url: url, ref: ref }).always(resp => $("#source-info").removeClass("loading"));
    $.get("/upload_whitelists/is_allowed.json", { url: url }).always(function(resp) {
      Upload.showWhitelistWarning(resp.is_allowed, resp.reason, resp.domain);
    });
  }

  e.preventDefault();
}

Upload.initialize_image = function() {
  var $image = $("#image");
  if (!$image.length) {
    return;
  }
  var width = $image.width();
  var height = $image.height();
  if (!width || !height) {
    // we errored out
    return;
  }
  $("#no-image-available").hide();
  $image.data("original-width", width);
  $image.data("original-height", height);
  Post.resize_image_to_window($image);
  Post.initialize_post_image_resize_to_window_link();
  Upload.update_scale();
  $("#image-resize-to-window-link").on("click.danbooru", Upload.update_scale);
}

Upload.toggle_commentary = function() {
  if ($(".artist-commentary").is(":visible")) {
    $("#toggle-artist-commentary").text("show »");
  } else {
    $("#toggle-artist-commentary").text("« hide");
  }

  $(".artist-commentary").slideToggle();
};

$(function() {
  Upload.initialize_all();
});

export default Upload
