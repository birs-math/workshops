json.event @event, :code, :name, :start_date, :end_date, :event_type, :location, :press_release
json.organizers @organizers
# Organizers stay public -- they are already advertised on www.birs.ca. The
# confirmed-participant list is not: see EventsController#member_list_visible?.
# The key is always emitted, so consumers parsing this response keep working.
json.members(@show_member_list ? @members : [])
