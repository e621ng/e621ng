import Cookie from "./cookie";
import Utility from "./utility";

function initSearch () {
  const $searchForm = $("#searchform");
  const $searchShow = $("#search-form-show-link");
  const $searchHide = $("#search-form-hide-link");
  if ($searchForm.length) {
    $searchShow.on("click", e => {
      e.preventDefault();
      $searchForm.fadeIn("fast");
      $searchShow.hide();
      $searchHide.show();
    });
    $searchHide.on("click", e => {
      e.preventDefault();
      $searchForm.fadeOut("fast");
      $searchShow.show();
      $searchHide.hide();
    });
  }
}

$(function () {
  // Account notices
  $(".dmail-notice-hide").on("click.danbooru", function (event) {
    event.preventDefault();
    $(".dmail-notice").hide();
    Cookie.put("hide_dmail_notice", "true");
  });

  $("#close-notice-link").on("click.danbooru", function (e) {
    $("#notice").fadeOut("fast");
    e.preventDefault();
  });

  $(".revert-item-link").on("click", e => {
    e.preventDefault();
    const target = $(e.target);
    const noun = target.data("noun");
    if (!confirm(`Are you sure you want to revert ${noun} to this version?`))
      return;
    const path = target.attr("href");
    $.ajax({
      method: "PUT",
      url: path,
      dataType: "json",
    }).done(() => {
      location.reload();
    }).fail(() => {
      Utility.error("Failed to revert to specified version.");
    });
  });

  initSearch();
});

window.submitInvisibleRecaptchaForm = function () {
  document.getElementById("signup-form").submit();
};
