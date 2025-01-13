import zxcvbn from "zxcvbn";
import Page from "./utility/page";

let Password = {};

Password.init_validation = function () {
  if (Page.matches("users", "new") || Page.matches("users", "create"))
    Password.bootstrap_input($("#user_password"), [$("#user_name"), $("#user_email")]);

  if (Page.matches("maintenance-user-password-resets", "edit"))
    Password.bootstrap_input($("#password"));

  if (Page.matches("maintenance-user-passwords", "edit"))
    Password.bootstrap_input($("#user_password"));
};

Password.bootstrap_input = function ($password, $inputs = []) {
  // Set up the UI
  $password.parent().addClass("password-input");

  const hint = $("<div>")
    .addClass("password-feedback")
    .insertAfter($password);
  const display = $("<div>")
    .addClass("password-strength")
    .insertAfter($password);
  const progress = $("<div>")
    .addClass("password-progress")
    .css("width", 0)
    .appendTo(display);

  // Listen to secondary input changes
  let extraData = getExtraData();
  for (const one of $inputs)
    one.on("input", () => {
      extraData = getExtraData();
    });

  // Listen to main input changes
  $password.on("input", () => {
    const analysis = zxcvbn($password.val() + "", extraData);

    progress.css("width", ((analysis.score * 25) + 10) + "%");
    hint.html("");
    if (analysis.feedback.warning)
      $("<span>")
        .text(analysis.feedback.warning)
        .addClass("password-warning")
        .appendTo(hint);
    for (const one of analysis.feedback.suggestions)
      $("<span>")
        .text(one)
        .appendTo(hint);
  });

  function getExtraData () {
    const output = [];
    for (const one of $inputs) {
      const val = one.val() + "";
      if (val) output.push(one.val() + "");
    }
    return output;
  }
};

$(() => {
  Password.init_validation();
});

export default Password;
