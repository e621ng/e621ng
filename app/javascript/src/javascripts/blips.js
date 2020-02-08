import Utility from './utility.js';

let Blip = {};

Blip.atme = function (id) {
  $.ajax({
    url: `/blips/${id}.json`,
    type: 'GET',
    dataType: 'json',
    accept: 'text/javascript',
    data: {
      id: id
    }
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
      id: id
    }
  }).done(function (data) {
    const stripped_body = data.body.replace(/\[quote\](?:.|\n|\r)+?\[\/quote\][\n\r]*/gm, "");
    $('#blip_body_for_')[0].value += `[quote]"${data.creator_name}":/user/show/${data.creator_id} said:
${stripped_body}
[/quote]

`;
    $("#blip_body_for_")[0].focus();
    $('#blip_response_to')[0].value = data.id;
  }).fail(function (data) {
    Utility.error(data.responseText);
  });
};

$(function() {
  if($("#c-blips").length) {
    $(".blip-atme-link").on('click', e => {
      Blip.atme($(e.target).data('bid'));
      e.preventDefault();
    });
    $(".blip-reply-link").on('click', e => {
      Blip.quote($(e.target).data('bid'));
      e.preventDefault();
    });
  }
});

export default Blip;
