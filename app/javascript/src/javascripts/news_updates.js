import Storage from './utility/storage';

let NewsUpdate = {};

NewsUpdate.initialize = function () {
  if (!$("#news").length) {
    return;
  }
  const key = parseInt($("#news").data("id"), 10);

  $('#news').on('click', function () {
    $('#news').toggleClass('open');
  });
  $('#news-closebutton').on('click', function () {
    $('#news').hide();
    Storage.Site.NewsUpdate = key;
  });
  if (Storage.Site.NewsUpdate < key)
    $("#news").show();
};

$(function () {
  NewsUpdate.initialize();
});

export default NewsUpdate
