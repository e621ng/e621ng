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


  // Profile menu, both desktop and mobile
  let avatarMenuOpen = false;

  // regular click
  $(".simple-avatar").on("click", (event) => {
    event.preventDefault();

    avatarMenuOpen = !avatarMenuOpen;
    simpleMenu.toggleClass("hidden");
    wrapper.removeClass("nav-toggled");
  });

  // click outside the menu
  $(window).on("mouseup", (event) => {
    if (!avatarMenuOpen) return;

    const target = $(event.target);
    if (target.closest(".nav-controls").length > 0) return;

    simpleMenu.addClass("hidden");
    avatarMenuOpen = false;
  });
};

$(() => {
  if (!$("nav.navigation").length) return;
  Navigation.init();
});

export default Navigation;
