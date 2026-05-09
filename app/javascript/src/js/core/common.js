import CStorage from "@/utility/StorageC";

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
    CStorage.hideDMailNotice = true;
  });

  $("#close-notice-link").on("click.danbooru", function (e) {
    $("#notice").fadeOut("fast");
    e.preventDefault();
  });

  // Prevent link navigation on first tap of a spoiler tag on touch devices.
  $(document).on("touchend.danbooru", ".spoiler", function (e) {
    if ($(e.target).closest("a", this).length && !$(this).hasClass("spoiler-revealed")) {
      e.preventDefault();
    }
    $(this).addClass("spoiler-revealed");
  });

  $(document).on("touchstart.danbooru", function (e) {
    if (!$(e.target).closest(".spoiler").length) {
      $(".spoiler.spoiler-revealed").removeClass("spoiler-revealed");
    }
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
      E621.Flash.error("Failed to revert to specified version.");
    });
  });

  initSearch();
});

window.submitInvisibleRecaptchaForm = function () {
  document.getElementById("signup-form").submit();
};
