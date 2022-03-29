$(function () {
  const current_state = localStorage.getItem("april_fools_2022");

  function durationInWords(milliseconds) {
    function numberEnding(number) {
      return (number > 1) ? "s" : "";
    }

    let temp = Math.floor(milliseconds / 1000);
    const days = Math.floor((temp %= 31536000) / 86400);
    const hours = Math.floor((temp %= 86400) / 3600);
    const minutes = Math.floor((temp %= 3600) / 60);
    const seconds = temp % 60;
    const hourString = hours + " hour" + numberEnding(hours);
    const minuteString = minutes + " minute" + numberEnding(minutes);
    const secondString = seconds + " second" + numberEnding(seconds);
    if (hours && minutes) {
      return hourString + " and " + minuteString;
    }
    if (minutes) {
      return minuteString + " and " + secondString;
    }
    if (hours) {
      return hourString;
    }
    if (seconds) {
      return secondString;
    }
    return "less than a second";
  }

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

  function getDuration() {
    return new Date().getTime() - localStorage.getItem("april_fools_2022_timestamp");
  }

  function updateText() {
    updateDurationLasted();
    updateDurationMessage();
  }

  function updateDurationLasted() {
    $(".usage-duration-on-load").text(durationInWords(getDuration()));
  }

  function updateDurationMessage() {
    const messages = {
      10000: "It's quite something, isn't it? We hope you like your new, improved browsing experience!",
      20000: "We're thinking about making it the new default, what do you think about that?",
      30000: "I'm just joking, don't worry. <sub><sub>Or am I?</sub></sub>",
      40000: "I probably suffered more while programming this.",
      50000: "Clearly I'm the victim here.",
      60000: "No idea why I did it to be honest.",
      80000: "Here's a <a style=\"color: yellow;\"href=\"https://www.youtube.com/watch?v=dQw4w9WgXcQ\">cute animal video</a> I found on youtube, to take your mind off things.",
      100000: "Please tell me you fell for that.",
      120000: "A rickroll, how original. I know.",
      150000: "Do you want to know where this theme is originally from?",
      180000: "It's an official theme from Windows 3.1 named 'Hot Dog Stand'.",
      210000: "Don't believe me? Go look it up yourself.",
      240000: "I'm slowly running out of thing to say, so I'll keep it short.",
      3600000: "Go buy a Bad Dragon or something.",
      999999999999: "You're still here? Why would you do that?"
    }
    const currentDuration = getDuration();
    if(currentDuration > 25000) {
      $("#april-fools-switch").show();
    } else {
      $("#april-fools-switch").hide();
    }
    for (const key of Object.keys(messages).map(k => parseInt(k)).sort((a, b) => a - b)) {
      if (currentDuration < key) {
        $(".duration-message").html(messages[key]);
        break;
      }
    }
  }

  function initOptIn() {
    switchTo("switch-message");
    updateText();
  }

  updateText();
  setInterval(() => {
    updateText();
  }, 1000);

  if (current_state == "opt-out") {
    switchTo("opt-out");
  } else if (current_state === "opt-in") {
    initOptIn();
  } else if (shouldShowInitialStep()) {
    $("#april-fools .initial").fadeIn();
  }

  $("#april-fools-yes").on("click", () => {
    localStorage.setItem("april_fools_2022", "opt-in");
    localStorage.setItem("april_fools_2022_old_theme", localStorage.getItem("theme"));
    localStorage.setItem("april_fools_2022_timestamp", new Date().getTime());
    setTheme("hotdog");
    switchTo("switch-message");
    initOptIn();
  });
  $("#april-fools-no").on("click", () => {
    localStorage.setItem("april_fools_2022", "opt-out");
    if (localStorage.getItem("april_fools_2022_old_theme")) {
      setTheme(localStorage.getItem("april_fools_2022_old_theme"))
    }
    switchTo("opt-out");
  });

  $("#april-fools-switch").on("click", () => {
    setTheme(localStorage.getItem("april_fools_2022_old_theme"));
    localStorage.setItem("april_fools_2022", "finished");
    switchTo("rollback-theme");
    $(".april-fools-duration-end").text(durationInWords(getDuration()));
  });

  $(".april-fools-reset").on("click", () => {
    localStorage.removeItem("april_fools_2022");
    localStorage.removeItem("april_fools_2022_old_theme");
    localStorage.removeItem("april_fools_2022_timestamp");
    location.reload();
  });
  $("#april-fools-dont-bother-me-again").on("click", () => {
    localStorage.setItem("april_fools_2022", "finished");
    if (localStorage.getItem("april_fools_2022_old_theme")) {
      setTheme(localStorage.getItem("april_fools_2022_old_theme"))
    }
    switchTo("opt-out-again")
  });

  $("#april-fools-done").on("click", () => {
    localStorage.setItem("april_fools_2022", "finished");
    switchTo("none")
  });
});
