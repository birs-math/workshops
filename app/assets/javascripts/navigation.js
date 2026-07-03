$(document).on('turbo:load', function() {

  $('#sidebar-toggle').click(function(e) {
    $('.toggle-arrows').toggleClass('fa-rotate-180');
  });

  function toggleSidebarCookie(state) {
    $.ajax({
      url: '/home/toggle_sidebar',
      type: 'POST',
      dataType: 'html',
      data: { toggle: state }
    });
  }

  $('[data-toggle="sidebar"]').click(function(e) {
    e.preventDefault();
    $('.app').toggleClass('sidenav-toggled');
    var state = $('.app').hasClass('sidenav-toggled');
    toggleSidebarCookie(state);
  });

  function removeActive() {
    $('ul.app-menu').find('a').each(function(index, element) {
      if (element.id) {
        $('#' + element.id).removeClass('active');
      }
    });
  }

  function expandMenu(item) {
    item.closest('li').addClass('is-expanded');
  }

  function yearLocation() {
    var path = window.location.pathname;
    var found = false;
    if (path.match(/location/)) {
      expandMenu($('#location-events'));
      var location = path.split('/').pop();
      $('#' + location + '-events').addClass('active');
      found = true;
    }

    if (path.match(/year/)) {
      expandMenu($('#year-events'));
      var year = path.match(/year\/(\d{4})/)[1];
      $('#' + year + '-events').addClass('active');
      found = true;
    }

    return found;
  }

  function updateActive(itemId) {
    removeActive();
    if (!yearLocation()) {
      if (itemId) {
        var item = $('#' + itemId);
        expandMenu(item);
        item.addClass('active');
      }
    }
  }

  $('.treeview-item').click(function(e) {
    removeActive();
    yearLocation();
    $(e.target).closest('li').addClass('active');
  });

  var pageClass = $('#current-page').attr('class');
  updateActive(pageClass);

  if ($(window).width() < 600) {
    toggleSidebarCookie(false);
    $('.app').removeClass('sidenav-toggled');
  }

  if ($('.app').hasClass('sidenav-toggled')) {
    $('.toggle-arrows').addClass('fa-rotate-180');
  }
});
