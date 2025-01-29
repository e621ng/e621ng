const Navigation = {};

Navigation.init = function () {
  const wrapper = $("html");
  $("#nav-toggle, .nav-offset-left, .nav-offset-bottom").on("click", (event) => {
    event.preventDefault();

    wrapper.toggleClass("nav-toggled");
  });
};

$(() => {
  if (!$("nav.navigation").length) return;
  Navigation.init();
});

export default Navigation;
