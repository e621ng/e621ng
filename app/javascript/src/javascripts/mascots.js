import LStorage from "./utility/storage";

const Mascots = {
  current: 0,
};

function showMascot (mascot) {
  $("body").css("background-image", "url(" + mascot.background_url + ")");
  $("body").css("background-color", mascot.background_color);
  $(".mascotbox").css("background-image", "url(" + mascot.background_url + ")");
  $(".mascotbox").css("background-color", mascot.background_color);

  const artistLink = $("<span>").text("Mascot by ").append($("<a>").text(mascot.artist_name).attr("href", mascot.artist_url));
  $("#mascot_artist").empty().append(artistLink);
}

function changeMascot () {
  const mascots = window.mascots;

  const availableMascotIds = Object.keys(mascots);
  const currentMascotIndex = availableMascotIds.indexOf(Mascots.current + "");

  Mascots.current = availableMascotIds[(currentMascotIndex + 1) % availableMascotIds.length];
  showMascot(mascots[Mascots.current]);

  LStorage.Site.Mascot = Mascots.current;
}

function initMascots () {
  $("#change-mascot").on("click", changeMascot);
  const mascots = window.mascots;
  Mascots.current = LStorage.Site.Mascot;
  if (!mascots[Mascots.current]) {
    const availableMascotIds = Object.keys(mascots);
    const mascotIndex = Math.floor(Math.random() * availableMascotIds.length);
    Mascots.current = availableMascotIds[mascotIndex];
  }
  showMascot(mascots[Mascots.current]);
}

$(function () {
  if ($("#c-static > #a-home").length)
    initMascots();
});
