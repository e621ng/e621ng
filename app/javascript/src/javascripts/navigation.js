import Offclick from "./utility/offclick";
import LStorage from "./utility/storage";

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

  // Anonymous users do not have an avatar menu
  const avatarMenu = $(".simple-avatar");
  if (avatarMenu.length === 0) return;
  if (!LStorage.has("e6.avatar.menu"))
    Navigation.sync_user_data();


  // Toggle menu on click
  let offclickHandler = null;
  avatarMenu.on("click", (event) => {
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

  // Load menu data on first click
  avatarMenu.one("click", async () => {
    const userID = avatarMenu.data("user-id");
    if (!userID) return;

    Navigation.build_avatar_menu();
    Navigation.sync_user_data();
  });
};

Navigation.sync_user_data = async function () {
  if (Navigation._syncInProgress)
    return Navigation._syncInProgress;

  Navigation._syncInProgress = fetch("/users/avatar_menu.json", {
    headers: {
      "Accept": "application/json",
      "Content-Type": "application/json",
    },
  }).then(response => {
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return response.json();
  }).then(data => {
    LStorage.Site.AvatarMenu = {
      has_uploads: data.has_uploads,
      has_favorites: data.has_favorites,
      has_sets: data.has_sets,
      has_comments: data.has_comments,
      has_forums: data.has_forums,
    };

    return data;
  }).catch(error => {
    console.error("Avatar menu: failed to load content", error);
    return Promise.reject(error);
  }).finally(() => {
    Navigation._syncInProgress = null;
  });

  return Navigation._syncInProgress;
};

Navigation.build_avatar_menu = function () {
  const userStats = LStorage.Site.AvatarMenu;

  $(".simple-avatar-menu")
    .toggleClass("has-uploads", userStats.has_uploads)
    .toggleClass("has-favorites", userStats.has_favorites)
    .toggleClass("has-sets", userStats.has_sets)
    .toggleClass("has-comments", userStats.has_comments)
    .toggleClass("has-forums", userStats.has_forum_posts);
};

$(() => {
  if (!$("nav.navigation").length) return;
  Navigation.init();
});

export default Navigation;
