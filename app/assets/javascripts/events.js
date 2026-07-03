$(document).on('turbo:load', function() {
  if ($('.events').length === 0) return;

  window.MathJax.Hub.Queue(["Typeset", MathJax.Hub]);

  if ($("body.events.edit").length > 0) {
    $('#start_date').datetimepicker({
      format: 'YYYY-MM-DD'
    });

    $('#end_date').datetimepicker({
      useCurrent: false,
      format: 'YYYY-MM-DD'
    });

    $('#start_date').on('dp.change', function(e) {
      $('#end_date').data("DateTimePicker").minDate(e.date);
    });

    $('#end_date').on('dp.change', function(e) {
      $('#start_date').data('DateTimePicker').maxDate(e.date);
    });
  }
});
