class CreateCustomFields < ActiveRecord::Migration[5.2]
  def change
    create_table :custom_fields do |t|
      t.references :event, foreign_key: true
      t.string :title
      t.integer :position, index: true
      t.string :description
      t.text :value
    end
  end
end
