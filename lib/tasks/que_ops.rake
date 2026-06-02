# frozen_string_literal: true

# que_ops.rake — read-only visibility into the que backlog for deploys.
#
# Email-burst safety is handled in code by AutomatedEmailPolicy (the
# ENABLE_AUTOMATED_EVENT_EMAILS kill-switch): while it is off, the mail-sending
# jobs run but send nothing, so a worker restart can drain the backlog harmlessly.
# This task just lets a deploy SEE what is queued.

namespace :que do
  MAIL_JOB_CLASSES = %w[
    Que::ReportEventStatisticsJob
    Que::DoubleCheckAttendanceJob
  ].freeze

  desc 'Report ready (due) vs future que jobs per class (read-only)'
  task backlog: :environment do
    conn = ActiveRecord::Base.connection
    unless conn.table_exists?('que_jobs')
      puts 'que:backlog — que_jobs table not present (nothing to report).'
      next
    end

    rows = conn.select_all(<<~SQL).to_a
      SELECT job_class,
             count(*) FILTER (WHERE finished_at IS NULL AND expired_at IS NULL AND run_at <= now()) AS ready,
             count(*) FILTER (WHERE finished_at IS NULL AND expired_at IS NULL AND run_at  > now()) AS future,
             count(*) AS total
      FROM que_jobs
      GROUP BY job_class
      ORDER BY ready DESC, job_class
    SQL

    puts format('%-46s %7s %8s %7s', 'job_class', 'READY', 'future', 'total')
    puts '-' * 71
    rows.each do |r|
      flag = MAIL_JOB_CLASSES.include?(r['job_class']) ? ' *mail' : ''
      puts format('%-46s %7s %8s %7s%s', r['job_class'], r['ready'], r['future'], r['total'], flag)
    end
    mail_ready = rows.select { |r| MAIL_JOB_CLASSES.include?(r['job_class']) }
                     .sum { |r| r['ready'].to_i }
    puts '-' * 71
    puts "Mail-sending jobs READY now: #{mail_ready}"
    enabled = defined?(AutomatedEmailPolicy) && AutomatedEmailPolicy.enabled?
    puts "AutomatedEmailPolicy.enabled? = #{enabled} " \
         "(#{enabled ? 'WILL SEND when run' : 'suppressed — safe to drain'})"
  end
end
