# app/models/person_merge_audit.rb
class PersonMergeAudit < ApplicationRecord
  belongs_to :source_person, class_name: 'Person'
  belongs_to :target_person, class_name: 'Person'

  validates :source_email, :target_email, presence: true
  validates :merge_reason, presence: true

  scope :completed, -> { where(completed: true) }
  scope :failed, -> { where(completed: false).where.not(error_message: nil) }
  scope :recent, -> { where('created_at > ?', 7.days.ago) }

  def self.create_for_merge(source:, target:, reason:, user: nil)
    create!(
      source_person: source,
      target_person: target,
      source_email: source.email,
      target_email: target.email,
      merge_reason: reason,
      initiated_by: user&.email || 'system',
      affected_memberships: source.membership_ids,
      affected_invitations: source.memberships.joins(:invitation).pluck('invitations.id')
    )
  end

  def mark_completed!
    update!(completed: true)
  end

  def mark_failed!(error)
    update!(completed: false, error_message: error.to_s)
  end
end