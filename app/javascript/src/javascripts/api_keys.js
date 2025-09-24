$(function() {
  const $durationSelect = $('#api_key_duration');
  const $customDateField = $('.custom-date-field');
  
  $durationSelect.on('change', function() {
    if ($(this).val() === 'custom') {
      $customDateField.show();
    } else {
      $customDateField.hide();
    }
  });
  
  $durationSelect.trigger('change');
});