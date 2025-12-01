# frozen_string_literal: true

class AddScheduledJobDisableSettings < ActiveRecord::Migration[6.1]
  def up
    # Add disable flags to Site settings
    # Both jobs are disabled by default until the scope bug fix is verified
    site_setting = Setting.find_by(var: 'Site')
    return unless site_setting

    site_value = site_setting.value || {}

    # Add disable flags (default to true = disabled for safety)
    site_value['disable_double_check_attendance_job'] = true
    site_value['disable_report_event_statistics_job'] = false

    site_setting.update!(value: site_value)
  end

  def down
    site_setting = Setting.find_by(var: 'Site')
    return unless site_setting

    site_value = site_setting.value || {}
    site_value.delete('disable_double_check_attendance_job')
    site_value.delete('disable_report_event_statistics_job')

    site_setting.update!(value: site_value)
  end
end
