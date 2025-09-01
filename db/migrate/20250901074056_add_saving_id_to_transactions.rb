class AddSavingIdToTransactions < ActiveRecord::Migration[7.1]
  def change
    add_column :transactions, :saving_id, :integer
  end
end
