import Cookie from './cookie'
import Utility from './utility'

function initSearch() {
  const $s = $("#searchform");
  const $sh = $("#searchform_hide");
  if ($s.length) {
    $("#search-form-show-link").on('click', e => {
      $s.fadeIn('fast');
      $sh.hide();
    });
    $("#search-form-hide-link").on('click', e => {
      $s.fadeOut('fast');
      $sh.show();
    });
    const urlSearch = new URLSearchParams(window.location.search);
    if (Array.from(urlSearch.keys()).filter(e => e.startsWith("search")).length) {
      $s.show();
      $sh.hide();
    }
  }
}

$(function() {
  // Account notices
  $("#hide-dmail-notice").on("click.danbooru", function(e) {
    var $dmail_notice = $("#dmail-notice");
    $dmail_notice.hide();
    var dmail_id = $dmail_notice.data("id");
    Cookie.put("hide_dmail_notice", dmail_id);
    e.preventDefault();
  });

  $("#close-notice-link").on("click.danbooru", function(e) {
    $('#notice').fadeOut("fast");
    e.preventDefault();
  });

  $("#desktop-version-link a").on("click.danbooru", function(e) {
    e.preventDefault();
    e.preventDefault();
    $.ajax("/users/" + Utility.meta("current-user-id") + ".json", {
      method: "PUT",
      data: {
        "user[disable_responsive_mode]": "true"
      }
    }).then(function() {
      location.reload();
    });
  });

  $(".revert-item-link").on('click', e => {
    e.preventDefault();
    const target = $(e.target);
    const noun = target.data('noun');
    if (!confirm(`Are you sure you want to revert ${noun} to this version?`))
      return;
    const path = target.attr('href');
    $.ajax({
      method: "PUT",
      url: path,
      dataType: 'json'
    }).done(data => {
      location.reload();
    }).fail(data => {
      Utility.error("Failed to revert to specified version.");
    })
  });

  initSearch();
});

window.submitInvisibleRecaptchaForm = function () {
  document.getElementById("signup-form").submit();
}
