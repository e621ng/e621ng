import LStorage from "@/utility/storage/Local";
import Page from "@/utility/Page";

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
  const $wrapper = $(wrapper);
  const button = $wrapper.find(".content-readmore");

  const showMoreText = "Show More";
  const showLessText = "Show Less";

  let expanded = false;
  const updateShowMore = () => {
    if (expanded) {
      $wrapper.removeClass("expanded");
    }

    if (wrapper.scrollHeight > wrapper.clientHeight) {
      $wrapper.addClass("expandable");
      if (expanded) {
        $wrapper.addClass("expanded");
      }
    } else {
      $wrapper.removeClass("expandable expanded");
      expanded = false;
      button.text(showMoreText);
    }
  };

  button.on("click", () => {
    expanded = !expanded;
    $wrapper.toggleClass("expanded", expanded);
    button.text(expanded ? showLessText : showMoreText);
  });

  // Update the "Show More" button visibility when DText sections (details tags)
  // are opened and closed.
  wrapper.addEventListener("toggle", (event) => {
    if (event.target.tagName.toLowerCase() === "details") {
      updateShowMore();
    }
  }, true);

  updateShowMore();
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
