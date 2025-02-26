import LStorage from "./utility/storage";

const Users = {};

Users.init_section = function ($wrapper) {
  const $header = $wrapper.find(".profile-section-header").first();
  const $body = $(".profile-section-body").first();
  const name = $wrapper.attr("name");
  if (!name || !$header.length || !$body.length) return;

  let state = LStorage.Users[name];
  if (state) $wrapper.removeClass("hidden");

  $header.on("click", () => {
    $wrapper.toggleClass("hidden", state);

    state = !state;
    LStorage.Users[name] = state;
  });
};

$(() => {
  for (const one of $((".profile-section")))
    Users.init_section($((one)));
});
