class AddSoftDeleteColumns < ActiveRecord::Migration[5.2]
  def change
    # Add soft delete columns for recovery
    add_column :memberships, :deleted_at, :datetime
    add_column :invitations, :deleted_at, :datetime
    add_column :people, :deleted_at, :datetime
    
    # Add indexes for performance
    add_index :memberships, :deleted_at
    add_index :invitations, :deleted_at
    add_index :people, :deleted_at
    
    # Add audit trail columns
    add_column :memberships, :deleted_by, :string
    add_column :memberships, :deletion_reason, :text
    add_column :invitations, :deleted_by, :string  
    add_column :invitations, :deletion_reason, :text
  end
end