$(function () {
  const $durationSelect = $("#api_key_duration");
  const $customDateField = $(".custom-date-field");
  const $neverExpiresWarning = $(".never-expires-warning");

  $durationSelect.on("change", function () {
    const value = $(this).val();

    if (value === "custom") {
      $customDateField.show();
      $neverExpiresWarning.hide();
    } else if (value === "never") {
      $customDateField.hide();
      $neverExpiresWarning.show();
    } else {
      $customDateField.hide();
      $neverExpiresWarning.hide();
    }
  });

  $durationSelect.trigger("change");
});
