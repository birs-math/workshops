# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2025_06_25_152951) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "confirm_email_changes", force: :cascade do |t|
    t.bigint "replace_person_id"
    t.bigint "replace_with_id"
    t.string "replace_email"
    t.string "replace_with_email"
    t.string "replace_code"
    t.string "replace_with_code"
    t.boolean "confirmed", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "priority", default: "normal"
    t.boolean "has_recent_invitations", default: false
    t.text "auto_merge_blocked_reason"
    t.string "reviewed_by"
    t.datetime "reviewed_at"
    t.index ["created_at"], name: "index_confirm_email_changes_on_created_at"
    t.index ["has_recent_invitations"], name: "index_confirm_email_changes_on_has_recent_invitations"
    t.index ["priority"], name: "index_confirm_email_changes_on_priority"
    t.index ["replace_code"], name: "index_confirm_email_changes_on_replace_code"
    t.index ["replace_person_id"], name: "index_confirm_email_changes_on_replace_person_id"
    t.index ["replace_with_code"], name: "index_confirm_email_changes_on_replace_with_code"
    t.index ["replace_with_id"], name: "index_confirm_email_changes_on_replace_with_id"
  end

  create_table "custom_fields", force: :cascade do |t|
    t.bigint "event_id"
    t.string "title"
    t.integer "position"
    t.string "description"
    t.text "value"
    t.index ["event_id"], name: "index_custom_fields_on_event_id"
    t.index ["position"], name: "index_custom_fields_on_position"
  end

  create_table "email_notifications", force: :cascade do |t|
    t.text "body", default: "", null: false
    t.string "path", null: false
    t.string "format", default: "html"
    t.string "handler", null: false
    t.boolean "default", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["path"], name: "index_email_notifications_on_path"
  end

  create_table "events", id: :serial, force: :cascade do |t|
    t.string "code"
    t.text "name"
    t.string "short_name"
    t.date "start_date"
    t.date "end_date"
    t.string "event_type"
    t.string "location"
    t.text "description"
    t.text "press_release"
    t.integer "max_participants"
    t.integer "door_code"
    t.string "booking_code"
    t.string "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "template", default: false
    t.string "time_zone"
    t.boolean "publish_schedule", default: false
    t.integer "confirmed_count", default: 0, null: false
    t.datetime "sync_time"
    t.string "subjects"
    t.integer "max_observers", default: 0, null: false
    t.boolean "cancelled", default: false
    t.boolean "online", default: false
    t.text "event_format"
    t.integer "max_virtual", default: 0, null: false
    t.integer "state", default: 0, null: false
    t.index ["code"], name: "index_events_on_code", unique: true
  end

  create_table "invitations", id: :serial, force: :cascade do |t|
    t.integer "membership_id"
    t.string "invited_by"
    t.string "code", null: false
    t.datetime "expires"
    t.datetime "invited_on"
    t.datetime "used_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "templates"
    t.datetime "deleted_at"
    t.string "deleted_by"
    t.text "deletion_reason"
    t.index ["deleted_at"], name: "index_invitations_on_deleted_at"
    t.index ["membership_id"], name: "index_invitations_on_membership_id"
  end

  create_table "lectures", id: :serial, force: :cascade do |t|
    t.integer "event_id", null: false
    t.integer "person_id"
    t.string "title"
    t.datetime "start_time"
    t.datetime "end_time"
    t.text "abstract"
    t.text "notes"
    t.string "filename"
    t.string "room"
    t.boolean "do_not_publish"
    t.boolean "tweeted"
    t.text "hosting_license"
    t.text "archiving_license"
    t.boolean "hosting_release"
    t.boolean "archiving_release"
    t.string "authors"
    t.string "copyright_owners"
    t.string "publication_details"
    t.string "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cmo_license"
    t.string "keywords"
    t.integer "legacy_id"
    t.string "watch_url"
    t.string "video_url"
    t.boolean "is_recording", default: false
    t.index ["event_id"], name: "index_lectures_on_event_id"
    t.index ["person_id"], name: "index_lectures_on_person_id"
  end

  create_table "memberships", id: :serial, force: :cascade do |t|
    t.integer "event_id"
    t.integer "person_id"
    t.date "arrival_date"
    t.date "departure_date"
    t.string "role"
    t.string "attendance"
    t.datetime "replied_at"
    t.boolean "share_email", default: true
    t.text "org_notes"
    t.text "staff_notes"
    t.string "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "sent_invitation", default: false
    t.boolean "own_accommodation", default: false
    t.boolean "has_guest", default: false
    t.boolean "guest_disclaimer", default: false
    t.string "special_info"
    t.string "stay_id"
    t.string "billing"
    t.boolean "reviewed", default: false
    t.string "room"
    t.string "invited_by"
    t.datetime "invited_on"
    t.boolean "share_email_hotel"
    t.string "room_notes"
    t.string "invite_reminders"
    t.integer "num_guests", default: 0, null: false
    t.datetime "deleted_at"
    t.string "deleted_by"
    t.text "deletion_reason"
    t.index ["deleted_at"], name: "index_memberships_on_deleted_at"
    t.index ["event_id"], name: "index_memberships_on_event_id"
    t.index ["person_id"], name: "index_memberships_on_person_id"
  end

  create_table "people", id: :serial, force: :cascade do |t|
    t.string "lastname"
    t.string "firstname"
    t.string "salutation"
    t.string "gender"
    t.string "email"
    t.string "cc_email"
    t.string "url"
    t.string "phone"
    t.string "fax"
    t.string "emergency_contact"
    t.string "emergency_phone"
    t.string "affiliation"
    t.string "department"
    t.string "title"
    t.string "address1"
    t.string "address2"
    t.string "address3"
    t.string "city"
    t.string "region"
    t.string "country"
    t.string "postal_code"
    t.string "academic_status"
    t.string "phd_year"
    t.text "biography"
    t.text "research_areas"
    t.integer "legacy_id"
    t.string "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "grants"
    t.datetime "deleted_at"
    t.bigint "confirm_email_change_id"
    t.index ["confirm_email_change_id"], name: "index_people_on_confirm_email_change_id"
    t.index ["deleted_at"], name: "index_people_on_deleted_at"
    t.index ["email"], name: "index_people_on_email", unique: true
  end

  create_table "person_merge_audits", force: :cascade do |t|
    t.bigint "source_person_id", null: false, comment: "Person being replaced"
    t.bigint "target_person_id", null: false, comment: "Person being merged into"
    t.string "source_email"
    t.string "target_email"
    t.json "affected_memberships", comment: "IDs of memberships moved/deleted"
    t.json "affected_invitations", comment: "IDs of invitations moved"
    t.text "merge_reason"
    t.string "initiated_by"
    t.boolean "completed", default: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_person_merge_audits_on_created_at"
    t.index ["source_person_id"], name: "index_person_merge_audits_on_source_person_id"
    t.index ["target_person_id"], name: "index_person_merge_audits_on_target_person_id"
  end

  create_table "que_jobs", comment: "7", force: :cascade do |t|
    t.integer "priority", limit: 2, default: 100, null: false
    t.datetime "run_at", default: -> { "now()" }, null: false
    t.text "job_class", null: false
    t.integer "error_count", default: 0, null: false
    t.text "last_error_message"
    t.text "queue", default: "default", null: false
    t.text "last_error_backtrace"
    t.datetime "finished_at"
    t.datetime "expired_at"
    t.jsonb "args", default: [], null: false
    t.jsonb "data", default: {}, null: false
    t.integer "job_schema_version", null: false
    t.jsonb "kwargs", default: {}, null: false
    t.index ["args"], name: "que_jobs_args_gin_idx", opclass: :jsonb_path_ops, using: :gin
    t.index ["data"], name: "que_jobs_data_gin_idx", opclass: :jsonb_path_ops, using: :gin
    t.index ["job_class"], name: "que_scheduler_job_in_que_jobs_unique_index", unique: true, where: "(job_class = 'Que::Scheduler::SchedulerJob'::text)"
    t.index ["job_schema_version", "queue", "priority", "run_at", "id"], name: "que_poll_idx", where: "((finished_at IS NULL) AND (expired_at IS NULL))"
    t.index ["kwargs"], name: "que_jobs_kwargs_gin_idx", opclass: :jsonb_path_ops, using: :gin
  end

  create_table "que_lockers", primary_key: "pid", id: :integer, default: nil, force: :cascade do |t|
    t.integer "worker_count", null: false
    t.integer "worker_priorities", null: false, array: true
    t.integer "ruby_pid", null: false
    t.text "ruby_hostname", null: false
    t.text "queues", null: false, array: true
    t.boolean "listening", null: false
    t.integer "job_schema_version", default: 1
  end

  create_table "que_scheduler_audit", primary_key: "scheduler_job_id", id: :bigint, default: nil, comment: "7", force: :cascade do |t|
    t.datetime "executed_at", null: false
  end

  create_table "que_scheduler_audit_enqueued", id: false, force: :cascade do |t|
    t.bigint "scheduler_job_id", null: false
    t.string "job_class", limit: 255, null: false
    t.string "queue", limit: 255
    t.integer "priority"
    t.jsonb "args", null: false
    t.bigint "job_id"
    t.datetime "run_at"
    t.index ["args"], name: "que_scheduler_audit_enqueued_args"
    t.index ["job_class"], name: "que_scheduler_audit_enqueued_job_class"
    t.index ["job_id"], name: "que_scheduler_audit_enqueued_job_id"
  end

  create_table "que_values", primary_key: "key", id: :text, force: :cascade do |t|
    t.jsonb "value", default: {}, null: false
  end

  create_table "schedules", id: :serial, force: :cascade do |t|
    t.integer "event_id", null: false
    t.integer "lecture_id"
    t.datetime "start_time"
    t.datetime "end_time"
    t.string "name"
    t.text "description"
    t.string "location"
    t.string "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "staff_item", default: false, null: false
    t.datetime "earliest"
    t.datetime "latest"
    t.index ["event_id"], name: "index_schedules_on_event_id"
  end

  create_table "sentmails", force: :cascade do |t|
    t.string "message_id"
    t.string "sender"
    t.string "recipient"
    t.string "subject"
    t.datetime "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_sentmails_on_message_id"
  end

  create_table "sessions", id: :serial, force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "settings", id: :serial, force: :cascade do |t|
    t.string "var", null: false
    t.text "value"
    t.integer "thing_id"
    t.string "thing_type", limit: 30
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["id"], name: "settings_id_key", unique: true
    t.index ["thing_type", "thing_id", "var"], name: "index_settings_on_thing_type_and_thing_id_and_var", unique: true
    t.index ["var"], name: "settings_var_key", unique: true
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: ""
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "person_id"
    t.string "invitation_token"
    t.datetime "invitation_created_at"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.integer "invitation_limit"
    t.integer "invited_by_id"
    t.string "invited_by_type"
    t.integer "invitations_count", default: 0
    t.integer "role", default: 0
    t.string "location"
    t.string "jti", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invitations_count"], name: "index_users_on_invitations_count"
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["person_id"], name: "index_users_on_person_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "custom_fields", "events"
  add_foreign_key "invitations", "memberships"
  add_foreign_key "lectures", "events"
  add_foreign_key "lectures", "people"
  add_foreign_key "memberships", "events"
  add_foreign_key "memberships", "people"
  add_foreign_key "people", "confirm_email_changes"
  add_foreign_key "que_scheduler_audit_enqueued", "que_scheduler_audit", column: "scheduler_job_id", primary_key: "scheduler_job_id", name: "que_scheduler_audit_enqueued_scheduler_job_id_fkey"
  add_foreign_key "schedules", "events"
end
