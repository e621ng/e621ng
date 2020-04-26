import LS from './local_storage'

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
    LS.put('hide_news_notice', key.toString());
  });
  if (parseInt(LS.get("hide_news_notice") || 0, 10) < key) {
    $("#news").show();
  }
};

$(function () {
  NewsUpdate.initialize();
});

export default NewsUpdate
