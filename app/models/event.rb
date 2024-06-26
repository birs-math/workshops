# app/models/event.rb
#
# Copyright (c) 2018 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

class Event < ApplicationRecord
  attr_accessor :data_import
  attr_reader :notice

  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :person
  has_many :schedules, dependent: :destroy
  has_many :lectures
  has_many :custom_fields, dependent: :destroy

  enum state: {
    imported: 0,
    published: 1,
    active: 2
  }

  accepts_nested_attributes_for :custom_fields

  before_save :clean_data
  before_update :update_name
  after_create :update_legacy_db
  after_create :enqueue_statistics_job
  after_create :enqueue_attendance_confirmation_job
  after_update :send_invitations, if: -> { state_changed_to_active? }

  validates :name, :start_date, :end_date, :location, :time_zone, presence: true
  validates :short_name, presence: true, if: :has_long_name
  validates :event_type, presence: true, if: :check_event_type
  validate :starts_before_ends
  validate :set_max_participants
  validate :has_format
  validates_inclusion_of :time_zone, in: ActiveSupport::TimeZone.all.map(&:name)
  validates :code, uniqueness: true, format: {
    with: /#{GetSetting.code_pattern}/,
    message: "- invalid code format. Must match: #{GetSetting.code_pattern}"
  }

  # app/models/concerns/event_decorators.rb
  include EventDecorators
  include EventRSVP

  # Find by code
  def to_param
    code
  end

  def self.find(param)
    param.to_s.match?(/\D/) ? find_by_code(param) : super
  end

  scope :past, lambda {
    where('end_date < ? AND template = ?', Date.current, false).order(:start_date).limit(100)
  }

  scope :future, lambda {
    where('end_date >= ? AND template = ?', Date.current, false).order(:start_date)
  }

  scope :year, lambda { |year|
    where("start_date >= '?-01-01' AND end_date <= '?-12-31' AND template = ?", year.to_i, year.to_i, false)
  }

  scope :in_range, lambda  { |start_date, end_date|
    where('start_date >= ? AND end_date <= ? AND template = false', start_date.to_s, end_date.to_s)
  }

  scope :location, lambda { |location|
    where('location = ? AND template = ?', location, false)
  }

  scope :kind, lambda { |kind|
    if kind == 'Research in Teams'
      # RITs stay plural
      where('event_type = ? AND template = ?', 'Research in Teams', false).order(:start_date)
    else
      where('event_type = ? AND template = ?', kind.titleize.singularize, false).order(:start_date)
    end
  }

  def staff_at_location
    User.staff.where(location: location)
  end

  def attendance_and_role(role:, attendance:)
    memberships.joins(:person).where(role: role, attendance: attendance)
  end

  def self.templates
    where('template = ?', true)
  end

  def check_event_type
    return true if GetSetting.site_setting('event_types').include?(event_type)

    types = GetSetting.site_setting('event_types').join(', ')
    errors.add(:event_type, "- event type must be one of: #{types}")
    false
  end

  def has_long_name
    return if data_import
    return unless name && name.length > 68

    if short_name.blank?
      errors.add(:short_name, '- if the name is > 68 characters, a shorter name is required to fit on name tags')
    elsif short_name.length > 68
      errors.add(:short_name, 'must be less than 68 characters long')
    end
  end

  def self.years
    all.map {|e| e.start_date.year.to_s}.uniq.sort.reverse
  end

  def starts_before_ends
    return unless (start_date && end_date) && (start_date > end_date)

    errors.add(:start_date, '- event must begin before it ends')
  end

  def set_sync_time
    self.sync_time = DateTime.current
    self.data_import = true # skip short_name validation
    save(touch: false)
  end

  def has_format
    return if event_formats.include?(event_format)

    errors.add(:event_format, "must be set to one of #{event_formats.join(', ')}")
  end

  def lock_date
    # Stop accepting some changes after Tuesday on the workshop week
    (start_date.beginning_of_week + 1.day).end_of_day
  end

  def send_invitations
    SendInvitationsJob.perform_later(event_id: id, invited_by: organizer.name)
  end

  private

  def update_legacy_db
    return unless Rails.env.production?

    LegacyConnector.new.add_event(self)
  end

  def enqueue_statistics_job
    Que::ReportEventStatisticsJob.new({}).schedule_job(self)
  end

  def enqueue_attendance_confirmation_job
    next_run = Rails.env.development? ? 10.minutes.from_now : one_month_before_start

    Que::DoubleCheckAttendanceJob.enqueue(event_id: id, job_options: { run_at: next_run })
  end

  def clean_data
    attributes.each_value { |v| v.strip! if v.respond_to?(:strip!) && !v.frozen? }
  end

  def set_max_defaults
    %w(participants virtual observers).each do |max_type|
      max_setting = 'max_' + max_type
      if send(max_setting).blank?
        max_num = GetSetting.send(max_setting, location) || 0
        write_attribute(max_setting, max_num)
      end
    end
  end

  def set_max_participants
    set_max_defaults if new_record?
    return unless event_format_changed?
    @notice = ''

    case event_format
    when 'Physical'
      if max_virtual >= 0
        self.max_virtual = 0
        @notice << 'Changed Maximum Virtual Participants to 0. '
      end
      if max_participants == 0
        self.max_participants = GetSetting.max_participants(location)
        @notice << "Changed Maximum Participants to #{max_participants}."
      end

    when 'Hybrid'
      if max_participants == 0
        self.max_participants = GetSetting.max_participants(location)
        @notice << "Changed Maximum Participants to #{max_participants}. "
      end
      if max_virtual == 0
        self.max_virtual = GetSetting.max_virtual(location)
        @notice << "Changed Maximum Virtual Participants to #{max_virtual}."
      end

    when 'Online'
      if max_participants > 0
        self.max_participants = 0
        @notice << 'Changed Maximum Participants to 0. '
      end
      if max_virtual == 0
        self.max_virtual = GetSetting.max_virtual(location)
        @notice << "Changed Maximum Virtual Participants to #{max_virtual}."
      end
    end
    @notice = nil if @notice.empty?
  end

  def event_formats
    formats = GetSetting.site_setting('event_formats')
    formats.kind_of?(Array) ? formats : ['Physical', 'Online', 'Hybrid']
  end

  def state_changed_to_active?
    saved_change_to_state? && state == 'active'
  end
end
