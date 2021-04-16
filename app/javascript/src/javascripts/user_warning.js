import Utility from './utility.js';

$(() => {
  $('.item-mark-user-warned').on('click', function(evt) {
    const target = $(evt.target);
    const type = target.data('item-type');
    const id = target.data('item-id');
    const record_type = target.data('record-type');

    $.ajax({
      type: "POST",
      url: `/${type}s/${id}/warning.json`,
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
