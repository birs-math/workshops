class AddStatusToEvents < ActiveRecord::Migration[5.2]
  def change
    add_column :events, :state, :integer, default: 0, null: false
  end
end
