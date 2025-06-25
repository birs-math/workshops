class AddConfirmEmailChangeIdToPeople < ActiveRecord::Migration[5.2]
  def change
    add_reference :people, :confirm_email_change, foreign_key: true
  end
end
