class AddProposalYearToProposals < ActiveRecord::Migration[5.2]
  def change
    add_column :proposals, :proposal_year, :string
  end
end
