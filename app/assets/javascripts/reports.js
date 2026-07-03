$(document).on('turbo:load', function() {
  $('#clear_all_default').on('click', function(e) {
    $('#default input:checkbox').prop('checked', false);
  });

  $(".clickable-row").on('click', function() {
    window.location = $(this).data("href");
  });
});
