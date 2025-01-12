const Navigation = {};

Navigation.init = function () {
  const wrapper = $("nav.navigation");
  $("#nav-toggle").on("click", (event) => {
    event.preventDefault();

    wrapper.toggleClass("toggled");
  });
};

$(() => {
  if (!$("nav.navigation").length) return;
  Navigation.init();
});

export default Navigation;
