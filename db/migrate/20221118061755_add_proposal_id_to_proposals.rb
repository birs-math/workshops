class AddProposalIdToProposals < ActiveRecord::Migration[5.2]
  def change
    add_column :proposals, :proposal_id, :integer
  end
end
