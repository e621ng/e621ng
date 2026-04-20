import Appearance from "@/utility/Appearance";

function bootstrapThemeSelector (input: HTMLElement) {
  const data = input.dataset;
  console.log("init", input, data);
  if (!data.a || !data.b) return;
  const value = Appearance[data.a][data.b];
  console.log("value", value);
  $(input).val(value + "").on("change", function () {
    console.log("change", this, data);
    Appearance[data.a][data.b] = $(this).val() + "";
  });
}

function bootstrapThemeCheckbox (input: HTMLElement) {
  const data = input.dataset;
  console.log("init", input, data);
  if (!data.a || !data.b) return;
  const value = Appearance[data.a][data.b];
  console.log("value", value);
  $(input).prop("checked", value).on("change", function () {
    console.log("change", this, data);
    Appearance[data.a][data.b] = $(this).is(":checked");
  });
}

$(() => {
  $("select[data-type='theme']").each(function () {
    bootstrapThemeSelector(this);
  });
  $("input[type='checkbox'][data-type='theme']").each(function () {
    bootstrapThemeCheckbox(this);
  });
});
