# frozen_string_literal: true

# Copyright (c) 2018 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

module EventMembersPresenter
  DEFAULT_FIELDS = I18n.t('event_report.default_fields').keys
  OPTIONAL_FIELDS = I18n.t('event_report.optional_fields').keys
  ALL_FIELDS = DEFAULT_FIELDS + OPTIONAL_FIELDS
  ATTENDANCE_TYPES = I18n.t('memberships.attendance').keys
  ROLES = I18n.t('memberships.roles').keys
  EVENT_FORMATS = I18n.t('events.formats').keys

  def cell_field_values
    @cell_field_values ||= {
      person_id: ->(mem) { mem.person_id },
      nserc_grant: ->(mem) { mem.person.grants.join(', ') },
      confirmed_count: ->(mem) { mem.event.confirmed_count },
      event_format: ->(mem) { mem.event.event_format },
      event_type: ->(mem) { mem.event.event_type },
      event_code: ->(mem) { mem.event.code },
      subjects: ->(mem) { mem.event.subjects },
      location: ->(mem) { mem.event.location },
      attendance: ->(mem) { mem.attendance },
      role: ->(mem) { mem.role },
      name: ->(mem) { mem.person.name },
      email: ->(mem) { mem.person.email },
      arriving_on: ->(mem) { mem.arrival_date },
      departing_on: ->(mem) { mem.departure_date },
      has_guests: ->(mem) { mem.has_guest },
      number_of_guests: ->(mem) { mem.num_guests },
      billing: ->(mem) { mem.billing },
      special_info: ->(mem) { mem.special_info },
      affiliation: ->(mem) { mem.person.affiliation },
      department: ->(mem) { mem.person.department },
      academic_status: ->(mem) { mem.person.academic_status },
      year_of_phd: ->(mem) { mem.person.phd_year },
      organizer_notes: ->(mem) { mem.org_notes },
      gender: ->(mem) { mem.person.gender },
      research_areas: ->(mem) { mem.person.research_areas },
      title: ->(mem) { mem.person.title }
    }
  end
end
