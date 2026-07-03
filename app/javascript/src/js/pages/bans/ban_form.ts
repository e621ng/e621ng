$(function () {
  const $customInput = $("#ban_duration_custom_input");
  if (!$customInput.length) return;

  $("input[name='ban_preset']").on("change", function () {
    const value = $(this).val();

    $customInput.toggleClass("hidden", value !== "custom");
    if (value == "custom") return;
    $customInput.val(value as string);
  });
});
