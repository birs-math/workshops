# app/models/concerns/soft_deletable.rb
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    scope :not_deleted, -> { where(deleted_at: nil) }
    scope :deleted, -> { where.not(deleted_at: nil) }
    scope :with_deleted, -> { unscope(where: :deleted_at) }
  end

  def soft_delete!(user: nil, reason: nil)
    update!(
      deleted_at: Time.current,
      deleted_by: user&.email || 'system',
      deletion_reason: reason
    )
  end

  def restore!
    update!(
      deleted_at: nil,
      deleted_by: nil,
      deletion_reason: nil
    )
  end

  def deleted?
    deleted_at.present?
  end
end