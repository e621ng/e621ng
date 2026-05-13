import LStorage from "@/utility/storage";
import Page from "@/utility/Page";
import CStorage from "@/utility/StorageC";

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
  let hideTrends = CStorage.hideSearchTrends;
  const trends = $("#home-trends"),
    trendsToggle = $("#home-trends h3");

  trendsToggle.on("click", () => {
    hideTrends = !hideTrends;
    CStorage.hideSearchTrends = hideTrends;
    trends.toggleClass("hidden", hideTrends);
    trendsToggle.attr("aria-expanded", !hideTrends);
  });
};

$(() => {
  if (!Page.matches("static", "home")) return;
  Home.init();
});

export default Home;
