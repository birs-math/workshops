class AddMaxVirtualToEvents < ActiveRecord::Migration[5.2]
  def change
    add_column :events, :max_virtual, :integer
  end
end
