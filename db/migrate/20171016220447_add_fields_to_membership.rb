class AddFieldsToMembership < ActiveRecord::Migration
  def change
    add_column :memberships, :billing, :string
    add_column :memberships, :reviewed, :boolean, default: false
  end
end
