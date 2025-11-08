import Offclick from "./utility/offclick";

const Navigation = {};

Navigation.init = function () {
  const wrapper = $("html");
  const simpleMenu = $(".simple-avatar-menu");

  // Mobile-only nav menu
  $("#nav-toggle, .nav-offset-left, .nav-offset-bott").on("click", (event) => {
    event.preventDefault();

    wrapper.toggleClass("nav-toggled");
    simpleMenu.addClass("hidden");
  });


  // regular click
  let offclickHandler = null;
  $(".simple-avatar").on("click", (event) => {
    event.preventDefault();

    // Register offclick handler on the first use
    if (offclickHandler === null)
      offclickHandler = Offclick.register(".simple-avatar", ".simple-avatar-menu", () => {
        simpleMenu.addClass("hidden");
      });

    offclickHandler.disabled = !offclickHandler.disabled;
    simpleMenu.toggleClass("hidden", offclickHandler.disabled);
    wrapper.removeClass("nav-toggled");
  });
};

$(() => {
  if (!$("nav.navigation").length) return;
  Navigation.init();
});

export default Navigation;
