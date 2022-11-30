class CreateProposal < ActiveRecord::Migration[5.2]
  def change
    create_table :proposals do |t|
      t.string :code
      t.string :workshop_name
      t.date :dates
      t.jsonb :participants
    end
  end
end
