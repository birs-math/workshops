class CreatePersonMergeAudit < ActiveRecord::Migration[5.2]
  def change
    create_table :person_merge_audits do |t|
      t.references :source_person, null: false, comment: "Person being replaced", index: true
      t.references :target_person, null: false, comment: "Person being merged into", index: true
      t.string :source_email
      t.string :target_email
      t.json :affected_memberships, comment: "IDs of memberships moved/deleted"
      t.json :affected_invitations, comment: "IDs of invitations moved"
      t.text :merge_reason
      t.string :initiated_by
      t.boolean :completed, default: false
      t.text :error_message
      
      t.timestamps
    end
    
    add_index :person_merge_audits, :created_at
  end
end