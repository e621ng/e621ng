$(function () {
  const current_state = localStorage.getItem("april_fools_2022");

  function setTheme(theme) {
    $(document.body).attr("data-th-main", theme);
    localStorage.setItem("theme", theme);
  }

  function shouldShowInitialStep() {
    const now = new Date();
    const isAprilFirst = now.getDate() == 1 && now.getMonth() == 3;
    return isAprilFirst && current_state === null;
  }

  function switchTo(to) {
    $("#april-fools div").hide();
    $("#april-fools ." + to).fadeIn();
  }

  if (shouldShowInitialStep()) {
    $("#april-fools .initial").fadeIn();
  }

  if (current_state == "opt-out") {
    $("#april-fools .opt-out").fadeIn();
  }

  $("#april-fools-yes").on("click", () => {
    localStorage.setItem("april_fools_2022", "opt-in");
    localStorage.setItem("april_fools_2022_old_theme", localStorage.getItem("theme"));
    localStorage.setItem("april_fools_2022_timestamp", new Date().getTime());
    setTheme("hotdog");
    switchTo("switch-message");
  });
  $("#april-fools-no").on("click", () => {
    localStorage.setItem("april_fools_2022", "opt-out");
    switchTo("opt-out");
  });

  $("#april-fools-switch").on("click", () => {
    setTheme(localStorage.getItem("april_fools_2022_old_theme"));
    localStorage.setItem("april_fools_2022", "finished");
    switchTo("rollback-theme");
  });
  $("#april-fools-keep").on("click", () => {
    localStorage.setItem("april_fools_2022", "finished");
    switchTo("keep-theme")
  });

  $("#april-fools-reset").on("click", () => {
    localStorage.removeItem("april_fools_2022");
    localStorage.removeItem("april_fools_2022_old_theme");
    localStorage.removeItem("april_fools_2022_timestamp");
    location.reload();
  });
  $("#april-fools-dont-bother-me-again").on("click", () => {
    localStorage.setItem("april_fools_2022", "finished");
    switchTo("opt-out-again")
  });

  const timestamp = localStorage.getItem("april_fools_2022_timestamp");
  const time_passed = new Date().getTime() - timestamp;

  if (current_state === "opt-in") {
    if (time_passed > 1000 * 60 * 5) {
      $("#april-fools .rollback-question").fadeIn();
    } else if (time_passed > 1000 * 60 * 2.5) {
      $("#april-fools .default-message").fadeIn();
    } else {
      $("#april-fools .switch-message").fadeIn();
    }
  }
});
