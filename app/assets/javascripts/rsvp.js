$(document).on('turbo:load', function() {
  if ($('.rsvp').length === 0) return;
  if ($('.feedback').length > 0) return;

  var REGION_COUNTRIES = ['canada', 'usa', 'u.s.a.', 'us', 'u.s.', 'united states', 'united states of america'];

  function regionCountry(country) {
    return REGION_COUNTRIES.indexOf(country) !== -1;
  }

  function changeRegionPlaceholder(country) {
    if (country === 'canada') {
      $('#rsvp_person_region')[0].placeholder = 'Province';
    } else {
      $('#rsvp_person_region')[0].placeholder = 'State';
    }
  }

  function showOrHideRegion(country) {
    if (regionCountry(country)) {
      $('#address-region').show();
      changeRegionPlaceholder(country);
    } else {
      $('#address-region').hide();
    }
  }

  var country = $('#rsvp_person_country').val().toLowerCase();

  if (country !== 'canada') {
    $('#canadian-grants').hide();
  }

  showOrHideRegion(country);

  $('#rsvp_person_country').change(function() {
    var c = $('#rsvp_person_country').val().toLowerCase();
    showOrHideRegion(c);
    if (c === 'canada') {
      $('#canadian-grants').show();
    } else {
      $('#canadian-grants').hide();
    }
  });

  $('#rsvp_membership_has_guest').change(function() {
    $('#rsvp_membership_guest_disclaimer').toggleClass('mandatory');
  });
});
