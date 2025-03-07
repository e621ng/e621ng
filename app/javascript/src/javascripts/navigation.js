import Page from "./utility/page";

const Navigation = {};

Navigation.init = function () {
  const wrapper = $("html");
  const simpleMenu = $(".simple-avatar-menu");

  $("#nav-toggle, .nav-offset-left, .nav-offset-bott").on("click", (event) => {
    event.preventDefault();

    wrapper.toggleClass("nav-toggled");
    simpleMenu.addClass("hidden");
  });

  if (Page.matches("static", "home")) return;
  $(".simple-avatar").on("click", (event) => {
    event.preventDefault();

    simpleMenu.toggleClass("hidden");
    wrapper.removeClass("nav-toggled");
  });
  $(".simple-avatar").on("dblclick", function () {
    // Silly approach, but it's 11pm and I don't care
    window.location = this.href;
  });
};

$(() => {
  if (!$("nav.navigation").length) return;
  Navigation.init();
});

export default Navigation;
