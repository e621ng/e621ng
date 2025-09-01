/* eslint-disable quotes */
import Utility from './utility.js';
import TextUtils from './utility/text_util.js';

let Blip = {};

Blip.atme = function (id) {
  $.ajax({
    url: `/blips/${id}.json`,
    type: 'GET',
    dataType: 'json',
    accept: 'text/javascript',
    data: {
      id: id,
    },
  }).done(function (data) {
    $('#blip_body_for_')[0].value += '@' + data.creator_name.replace(/ /g, "_") + ': ';
    $("#blip_body_for_")[0].focus();
    $('#blip_response_to')[0].value = data.id;
  }).fail(function (data) {
    Utility.error(data.responseText);
  });
};

Blip.quote = function (id) {
  $.ajax({
    url: `/blips/${id}.json`,
    type: 'GET',
    dataType: 'json',
    accept: 'text/javascript',
    data: {
      id: id,
    },
  }).done(function (data) {
    const $textarea = $("#blip_body_for_");
    TextUtils.processQuote($textarea, data.body, data.creator_name, data.creator_id);
    $textarea.selectEnd();

    $('#blip_response_to')[0].value = data.id;
  }).fail(function (data) {
    Utility.error(data.responseText);
  });
};

Blip.initialize_all = function () {
  if ($("#c-blips").length) {
    $(".blip-atme-link").on('click', e => {
      Blip.atme($(e.target).data('bid'));
      e.preventDefault();
    });
    $(".blip-reply-link").on('click', e => {
      Blip.quote($(e.target).data('bid'));
      e.preventDefault();
    });
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
