import LStorage from "./utility/storage";
import Page from "./utility/page";

const Mascots = {
  current: 0,
};

Mascots.showMascot = function (mascot) {
  $("body").css({
    "--bg-image": `url("${mascot.background_url}")`,
    "--bg-color": mascot.background_color,
  });

  $("#mascot-artist")
    .text("Mascot by ")
    .append($("<a>").text(mascot.artist_name).attr("href", mascot.artist_url));
};

Mascots.changeMascot = function (event) {
  event.preventDefault();

  const mascots = window.mascots;

  const availableMascotIds = Object.keys(mascots);
  const currentMascotIndex = availableMascotIds.indexOf(Mascots.current + "");

  Mascots.current = availableMascotIds[(currentMascotIndex + 1) % availableMascotIds.length];
  Mascots.showMascot(mascots[Mascots.current]);

  LStorage.Site.Mascot = Mascots.current;
};

Mascots.initMascots = function () {
  const mascots = window.mascots;
  Mascots.current = LStorage.Site.Mascot;
  if (!mascots[Mascots.current]) {
    const availableMascotIds = Object.keys(mascots);
    const mascotIndex = Math.floor(Math.random() * availableMascotIds.length);
    Mascots.current = availableMascotIds[mascotIndex];
  }
  Mascots.showMascot(mascots[Mascots.current]);

  $("#mascot-swap").on("click", Mascots.changeMascot);
};

$(function () {
  if (!Page.matches("static", "home")) return;
  Mascots.initMascots();
});

export default Mascots;
