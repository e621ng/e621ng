const Navigation = {};

Navigation.init = function () {
  const wrapper = $("body");
  $("#nav-toggle").on("click", (event) => {
    event.preventDefault();

    wrapper.toggleClass("nav-toggled");
  });
};

$(() => {
  if (!$("nav.navigation").length) return;
  Navigation.init();
});

export default Navigation;
