# frozen_string_literal: true

module Que
  class ReportEventStatisticsJob < Job
    def run(event_id:)
      return if job_disabled?

      event = Event.find_by(id: event_id)
      return if event.nil? # Event was deleted, nothing to do

      EventStatisticsMailer.notify(event_id: event_id).deliver_now

      schedule_job(event)
    end

    def schedule_job(event)
      next_run = next_run_at(event)

      return if event.start_date_in_time_zone < next_run

      self.class.enqueue(event_id: event.id, job_options: { run_at: next_run }) if event.present?
    end

    def next_run_at(event)
      if ::Rails.env.production? || ::Rails.env.test?
        production_run_at(event)
      else
        development_run_at(event)
      end
    end

    def production_run_at(event)
      2.month.from_now(Date.today.in_time_zone(event.time_zone)).beginning_of_day
    end

    def development_run_at(event)
      1.hour.from_now(DateTime.now.in_time_zone(event.time_zone))
    end

    def job_disabled?
      site_settings = Setting.find_by(var: 'Site')&.value || {}
      site_settings['disable_report_event_statistics_job'] == true
    end
  end
end
