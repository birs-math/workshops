$(document).on('turbo:load', function() {
  if ($('.memberships').length === 0) return;

  $(".spinner").hide();
  $('#add-members').show();

  // Memberships list: hide shown tab-pane if member name is re-clicked
  $('a[data-toggle="list"]').click(function(e) {
    $(e.target.hash).toggle();
  });

  $('#new-people tr').find('.person-data').each(function(i, field) {
    if (field.value.length === 0) {
      $(field).addClass('has-error');
    }
  });

  $('.person-data').change(function(e) {
    $('#new-people tr').find('.person-data').each(function(i, field) {
      if (field.value.length > 0) {
        $(field).removeClass('has-error');
      } else {
        $(field).addClass('has-error');
      }
    });
  });

  $('#add-members-submit').click(function(e) {
    $('#add-members').hide();
    $(".spinner").show();
  });

  // Enable tooltips & popovers
  $('[data-toggle="popover"]').popover();
  $('[data-toggle="tooltip"]').tooltip();

  // Show legend for invited & undecided overdue replies
  if ($('.invited-members').find('.reply-due').length > 0) {
    $('#Invited-legend').show();
  }
  if ($('.undecided-members').find('.reply-due').length > 0) {
    $('#Undecided-legend').show();
  }

  // Show/hide grants on self edit form
  var country = $('#membership_person_attributes_country').val();
  if (country) {
    if (country.toLowerCase() !== 'canada') {
      $('#canadian-grants').hide();
    }

    $('#membership_person_attributes_country').change(function() {
      var c = $('#membership_person_attributes_country').val().toLowerCase();
      if (c === 'canada') {
        $('#canadian-grants').show();
      } else {
        $('#canadian-grants').hide();
      }
    });
  }

  // Memberships invite page buttons
  function setChecked(status, value) {
    $("." + status).each(function(i, elm) {
      elm.checked = value;
    });
  }

  function checkInvert(status) {
    $("." + status).each(function(i, elm) {
      elm.checked = !elm.checked;
    });
  }

  $('.all-button').click(function(e) {
    var status = /^(.+)-all$/.exec(e.target.id)[1];
    setChecked(status, true);
  });

  $('.none-button').click(function(e) {
    var status = /^(.+)-none$/.exec(e.target.id)[1];
    setChecked(status, false);
  });

  $('.invert-button').click(function(e) {
    var status = /^(.+)-invert$/.exec(e.target.id)[1];
    checkInvert(status);
  });

  // Attendance status of the Submit button clicked & display confirmation
  $('.submit-button').click(function(e) {
    var status = /^(.+)-submit$/.exec(e.target.id)[1];
    var msg = 'This will send all selected Not Yet Invited Members an email, inviting them to attend this workshop. Are you sure you want to proceed?';
    if (status !== 'not-yet-invited') {
      msg = 'This will send all selected ' + status.charAt(0).toUpperCase() + status.slice(1) +
        ' Members an email, reminding them them to respond to the previously sent invitation. Are you sure you want to proceed?';
    }
    return confirm(msg);
  });
});
