import LStorage from "./utility/storage";

let NewsUpdate = {};

NewsUpdate.initialize = function () {
  if (!$("#news").length) {
    return;
  }
  const key = parseInt($("#news").data("id"), 10);

  $("#news").on("click", function () {
    $("#news").toggleClass("open");
  });
  $("#news-closebutton").on("click", function () {
    $("#news").hide();
    LStorage.Site.NewsID = key;
  });
  if (LStorage.Site.NewsID < key) {
    $("#news").show();
  }
};

$(function () {
  NewsUpdate.initialize();
});

export default NewsUpdate;
