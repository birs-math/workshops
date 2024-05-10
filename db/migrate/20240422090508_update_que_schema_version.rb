class UpdateQueSchemaVersion < ActiveRecord::Migration[5.2]
  def change
    Que::Scheduler::Migrations.migrate!(version: 7)
    Que::Scheduler::Migrations.reenqueue_scheduler_if_missing
  end
end
