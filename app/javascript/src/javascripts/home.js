import LStorage from "./utility/storage";
import Page from "./utility/page";

const Home = {};

Home.init = function () {

  const $form = $("#home-search-form");
  const $tags = $("#tags");

  let isEmpty = !$tags.val();
  let wasEmpty = isEmpty;
  if (isEmpty) $form.addClass("empty");

  $tags.on("input", () => {
    wasEmpty = isEmpty;
    isEmpty = !$tags.val();

    if (isEmpty && !wasEmpty) $form.addClass("empty");
    else if (!isEmpty && wasEmpty) $form.removeClass("empty");
  });

  $(".home-buttons a").on("click", (event) => {
    if (isEmpty) return; // Act like regular links

    event.preventDefault();
    const extraTags = $(event.currentTarget).attr("tags");
    if (extraTags) {
      $tags.val((index, value) => {
        return value + " " + extraTags;
      });
    }

    $form.trigger("submit");
    return false;
  });

  /* Trends toggle */
  let trendsShown = LStorage.Site.RisingShown;
  const trends = $("#home-trends"),
    trendsToggle = $("#home-trends h3");
  if (trendsShown) {
    trends.removeClass("hidden");
    trendsToggle.attr("aria-expanded", "true");
  }
  window.setTimeout(() => trends.addClass("animated"), 500); // Don't animate on page load

  trendsToggle.on("click", () => {
    trendsShown = !trendsShown;
    LStorage.Site.RisingShown = trendsShown;
    trends.toggleClass("hidden", !trendsShown);
    trendsToggle.attr("aria-expanded", trendsShown);
  });
};

$(() => {
  if (!Page.matches("static", "home")) return;
  Home.init();
});

export default Home;
