class AddSoftDeleteAuditColumnsToPeople < ActiveRecord::Migration[5.2]
  def change
    add_column :people, :deleted_by, :string
    add_column :people, :deletion_reason, :text
    add_index :people, :deleted_by
  end
end
