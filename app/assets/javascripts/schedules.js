$(document).on('turbo:load', function() {
  if ($('.schedule').length === 0) return;

  window.MathJax.Hub.Queue(["Typeset", MathJax.Hub]);

  if ($('#earliest_hour').length > 0) {
    var ehour = parseInt($('#earliest_hour').val(), 10);
    $('#schedule_start_time_4i option:lt(' + ehour + ')').remove();
    var emin = parseInt($('#earliest_minute').val(), 10);

    $('#schedule_start_time_4i').click(function(event) {
      var selected = $('#schedule_start_time_4i option').filter(':selected').text();
      if (parseInt(selected, 10) === ehour) {
        $('#schedule_start_time_5i option:lt(' + emin + ')').remove();
      } else {
        // (.length, not jQuery .size() — removed in jQuery 3)
        if ($('#schedule_start_time_5i option').length < 60) {
          for (var min = emin - 1; min >= 0; min--) {
            var label = min < 10 ? '0' + min : String(min);
            $('#schedule_start_time_5i').prepend('<option value="' + label + '">' + label + '</option>');
          }
        }
      }
    });
  }

  if ($('#latest_hour').length > 0) {
    var lhour = parseInt($('#latest_hour').val(), 10);
    $('#schedule_end_time_4i option:gt(' + lhour + ')').remove();
    var lmin = parseInt($('#latest_minute').val(), 10);

    $('#schedule_end_time_4i').click(function(event) {
      var selected = $('#schedule_end_time_4i option').filter(':selected').text();
      if (parseInt(selected, 10) === lhour) {
        $('#schedule_end_time_5i option:gt(' + lmin + ')').remove();
      } else {
        if ($('#schedule_end_time_5i option').length < 60) {
          for (var min = lmin + 1; min <= 59; min++) {
            var label = min < 10 ? '0' + min : String(min);
            $('#schedule_end_time_5i').append('<option value="' + label + '">' + label + '</option>');
          }
        }
      }
    });
  }

  $('#print-button').click(function(event) {
    print();
  });

  if (/firefox|msie/i.test(navigator.userAgent)) {
    $('select').removeClass('form-control');
  }

  function publishSchedule(state) {
    $.ajax({
      url: '/events/' + $('#event-code').text() + '/schedule/publish_schedule',
      type: 'POST',
      dataType: 'html',
      data: { publish_schedule: state },
      error: function() {
        alert('Failed to change publishing status! :(');
      }
    });
  }

  $('#publish_schedule').change(function() {
    publishSchedule(this.checked ? 'true' : 'false');
  });

  $('.item-link').click(function(event) {
    event.preventDefault();
    var descId = this.id.replace("link", "description");
    var iconId = this.id.replace("link", "icon");
    $('#' + descId).fadeToggle();
    if ($('#' + iconId).hasClass('fa-toggle-down')) {
      $('#' + iconId).removeClass('fa-toggle-down').addClass('fa-toggle-up');
    } else {
      $('#' + iconId).removeClass('fa-toggle-up').addClass('fa-toggle-down');
    }
  });

  if ($("body.schedule.new").length > 0 || $("body.schedule.edit").length > 0) {
    var date = $('#day').val();
    var startHour = $('#schedule_start_time_4i').find(":selected").text();
    var startMin = $('#schedule_start_time_5i').find(":selected").text();
    var endHour = $('#schedule_end_time_4i').find(":selected").text();
    var endMin = $('#schedule_end_time_5i').find(":selected").text();

    var jsdate = date.replace(/-/g, '/');
    var startTime = new Date(jsdate + ' ' + startHour + ':' + startMin + ':00');
    var endTime = new Date(jsdate + ' ' + endHour + ':' + endMin + ':00');
    var datediff = endTime.getTime() - startTime.getTime();

    function updateEndTime(diff) {
      var newStartHour = $('#schedule_start_time_4i').find(":selected").text();
      var newStartMin = $('#schedule_start_time_5i').find(":selected").text();

      if (newStartHour === '23') {
        $('#schedule_end_time_4i').val(newStartHour);
        if (diff < 60 * 59 * 1000) {
          $('#schedule_end_time_5i').val(('0' + (newStartMin + diff)).slice(-2));
        } else {
          $('#schedule_end_time_5i').val('59');
        }
      } else {
        var newStartTime = new Date(jsdate + ' ' + newStartHour + ':' + newStartMin + ':00');
        var newEndTime = new Date(newStartTime.getTime() + diff);
        $('#schedule_end_time_4i').val(('0' + newEndTime.getHours()).slice(-2));
        $('#schedule_end_time_5i').val(('0' + newEndTime.getMinutes()).slice(-2));
      }
    }

    $('#schedule_start_time_4i').on('change', function(e) {
      updateEndTime(datediff);
    });

    $('#schedule_start_time_5i').on('change', function(e) {
      updateEndTime(datediff);
    });
  }
});
