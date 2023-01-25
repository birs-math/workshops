$(document).on 'turbolinks:load', ->
  attendanceSelectors = ['#confirmed', '#invited', '#undecided', '#not_yet_invited', '#declined']

  listendOnAttendaceChange = (selector) ->
    if !$(selector).is(':checked')
      atLeastOneSelected = attendanceSelectors.some (attendance) -> $(attendance).is(':checked')
      unless atLeastOneSelected
        $(selector).prop('checked', true)

  attendanceSelectors.forEach (selector) ->
    $(selector).on 'click', (e) -> listendOnAttendaceChange(selector)
