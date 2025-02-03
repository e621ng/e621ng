import Page from "./utility/page";

const Home = {};

Home.init = function () {

  const $form = $("#home-search-form");
  const $tags = $("#tags");
  console.log("init");

  let isEmpty = !$tags.val();
  let wasEmpty = isEmpty;
  if (isEmpty) $form.addClass("empty");
  console.log("input", isEmpty, wasEmpty);

  $tags.on("input", () => {
    wasEmpty = isEmpty;
    isEmpty = !$tags.val();
    console.log("input", isEmpty, wasEmpty);

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
};

$(() => {
  if (!Page.matches("static", "home")) return;
  Home.init();
});

export default Home;
