$(document).on('turbo:load', function() {
  if ($(".settings").length === 0) return;

  $('.nav-tabs a').click(function(e) {
    $('div.tab-pane').removeClass('active');
    $('div#' + this.id).addClass('active');
  });
});
