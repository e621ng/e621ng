/* eslint-disable quotes */
import Utility from './utility.js';
import TextUtils from './utility/text_util.js';

let Blip = {};

Blip.atme = function (e) {
  e.preventDefault();
  const $parent = $(e.target).parents("article.blip");
  const creator = $parent.data("creator");
  const blipId = $parent.data("blip-id");

  $('#blip_body_for_')[0].value += '@' + String(creator || "").replace(/ /g, "_") + ': ';
  $("#blip_body_for_")[0].focus();
  $('#blip_response_to')[0].value = blipId;
};

Blip.quote = function (e) {
  e.preventDefault();
  const $parent = $(e.target).parents("article.blip");
  const blipId = $parent.data("blip-id");

  $.ajax({
    url: `/blips/${blipId}.json`,
    type: 'GET',
    dataType: 'json',
    accept: 'text/javascript',
  }).done(function (data) {
    const $textarea = $("#blip_body_for_");
    TextUtils.processQuote($textarea, data.body, $parent.data("creator"), $parent.data("creator-id"));
    $textarea.selectEnd();

    $('#blip_response_to')[0].value = blipId;
  }).fail(function (data) {
    Utility.error(data.responseText);
  });
};

Blip.initialize_all = function () {
  if ($("#c-blips").length) {
    $(".blip-atme-link").on('click', Blip.atme);
    $(".blip-reply-link").on('click', Blip.quote);
  }
};

Blip.reinitialize_all = function () {
  if ($("#c-blips").length) {
    $(".blip-atme-link").off('click');
    $(".blip-reply-link").off('click');
    Blip.initialize_all();
  }
};

$(function () {
  Blip.initialize_all();
});

export default Blip;
