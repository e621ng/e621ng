$(function () {
  const current_state = localStorage.getItem("april_fools_2022");

  function setTheme(theme) {
    $(document.body).attr("data-th-main", theme);
    localStorage.setItem("theme", theme);
  }

  function switchTo(to) {
    $("#april-fools div").hide();
    $("#april-fools ." + to).fadeIn();
  }

  if (current_state === "opt-in") {
    switchTo("switch-message");
  }

  $("#april-fools-switch").on("click", () => {
    setTheme(localStorage.getItem("april_fools_2022_old_theme"));
    localStorage.setItem("april_fools_2022", "finished");
    switchTo("none");
  });
});
