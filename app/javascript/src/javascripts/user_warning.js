import Utility from './utility.js';

$(() => {
  $('.item-mark-user-warned').on('click', function(evt) {
    evt.preventDefault();
    const target = $(evt.target);
    const type = target.data('item-route');
    const id = target.data('item-id');
    const record_type = target.data('record-type');

    $.ajax({
      type: "POST",
      url: `/${type}/${id}/warning.json`,
      data: {
        'record_type': record_type
      },
    }).done(function(data) {
      location.reload();
    }).fail(function(data) {
      Utility.error("Failed to mark as warned.");
    });
  });
});
