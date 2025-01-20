import LStorage from "./utility/storage";

let NewsUpdate = {};

NewsUpdate.initialize = function () {
  if (!$("#news").length) return;
  const key = parseInt($("#news").data("id"), 10);

  // Toggle news section open and closed
  let newsOpen = false;
  $("#news-header, #news-show").on("click", (event) => {
    event.preventDefault();
    console.log("click");

    newsOpen = !newsOpen;
    $("#news").toggleClass("open", newsOpen);
    $("#news-show").text(newsOpen ? "Hide" : "Show");

    return false; // Prevent triggering both elements at once
  });

  // Dismiss the news section
  $("#news-dismiss").on("click", (event) => {
    event.preventDefault();

    $("#news").hide();
    LStorage.Site.NewsID = key;

    return false;
  });

  // Show if there are new news updates
  if (LStorage.Site.NewsID < key) {
    $("#news").show();
  }
};

$(function () {
  NewsUpdate.initialize();
});

export default NewsUpdate;
