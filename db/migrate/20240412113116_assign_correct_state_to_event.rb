class AssignCorrectStateToEvent < ActiveRecord::Migration[5.2]
  def change
    Event.imported.where('end_date < ?', Date.current.end_of_year).update_all(state: 2)
  end
end
