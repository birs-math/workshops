require "administrate/base_dashboard"

class ConfirmEmailChangeDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    people: Field::HasMany,
    id: Field::Number,
    replace_person: Field::BelongsTo.with_options(class_name: "Person"),
    replace_with: Field::BelongsTo.with_options(class_name: "Person"),
    replace_person_id: Field::Number,
    replace_with_id: Field::Number,
    replace_email: Field::String,
    replace_with_email: Field::String,
    replace_code: Field::String,
    replace_with_code: Field::String,
    confirmed: Field::Boolean,
    priority: Field::String,
    has_recent_invitations: Field::Boolean,
    auto_merge_blocked_reason: Field::Text,
    reviewed_by: Field::String,
    reviewed_at: Field::DateTime,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = [
    :id,
    :replace_person,
    :replace_with,
    :priority,
    :has_recent_invitations,
    :confirmed,
    :created_at,
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = [
    :id,
    :replace_person,
    :replace_with,
    :replace_email,
    :replace_with_email,
    :priority,
    :has_recent_invitations,
    :auto_merge_blocked_reason,
    :confirmed,
    :reviewed_by,
    :reviewed_at,
    :created_at,
    :updated_at,
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = [
    :people,
    :replace_person_id,
    :replace_with_id,
    :replace_email,
    :replace_with_email,
    :replace_code,
    :replace_with_code,
    :confirmed,
  ].freeze

  # Overwrite this method to customize how confirm email changes are displayed
  # across all pages of the admin dashboard.
  #
  def display_resource(confirm_email_change)
    person1_name = confirm_email_change.replace_person&.name || "Person #{confirm_email_change.replace_person_id}"
    person2_name = confirm_email_change.replace_with&.name || "Person #{confirm_email_change.replace_with_id}"
    status = confirm_email_change.confirmed? ? "[RESOLVED]" : "[PENDING]"
    priority_flag = confirm_email_change.priority == 'high' ? "🔴" : ""
    "#{priority_flag}#{status} #{person1_name} ↔ #{person2_name}"
  end
end
