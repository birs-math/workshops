class EnhanceConfirmEmailChange < ActiveRecord::Migration[5.2]
  def change
    # Add priority and context fields
    add_column :confirm_email_changes, :priority, :string, default: 'normal'
    add_column :confirm_email_changes, :has_recent_invitations, :boolean, default: false
    add_column :confirm_email_changes, :auto_merge_blocked_reason, :text
    add_column :confirm_email_changes, :reviewed_by, :string
    add_column :confirm_email_changes, :reviewed_at, :datetime
    
    # Add indexes
    add_index :confirm_email_changes, :priority
    add_index :confirm_email_changes, :has_recent_invitations
    add_index :confirm_email_changes, :created_at
  end
end