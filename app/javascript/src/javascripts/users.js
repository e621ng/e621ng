import LStorage from "./utility/storage";
import Page from "./utility/page";

const Users = {};

Users.init_section = function ($wrapper) {
  const $header = $wrapper.find(".profile-section-header").first();
  const $body = $(".profile-section-body").first();
  const name = $wrapper.attr("name");
  if (!name || !$header.length || !$body.length) return;

  let state = LStorage.Users[name];
  if (state) $wrapper.removeClass("hidden").attr("aria-expanded", "true");

  $header.on("click", () => {
    $wrapper.toggleClass("hidden", state)
      .attr("aria-expanded", state ? "false" : "true");

    state = !state;
    LStorage.Users[name] = state;
  });
};

Users.init_readmore = function (wrapper) {
  if (wrapper.clientHeight >= wrapper.scrollHeight) return;
  const $wrapper = $(wrapper).addClass("expandable");

  let expanded = false;
  const button = $wrapper.find(".content-readmore").on("click", () => {
    expanded = !expanded;
    $wrapper.toggleClass("expanded", expanded);
    button.text(expanded ? "Show Less" : "Show More");
  });
};

$(() => {
  if (!Page.matches("users", "show")) return;

  // Show-all on about sections
  for (const one of $(".profile-readmore .content"))
    Users.init_readmore(one);

  // Staff-only sections
  for (const one of $((".profile-section")))
    Users.init_section($(one));
});
