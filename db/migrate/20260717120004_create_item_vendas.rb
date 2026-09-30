class CreateItemVendas < ActiveRecord::Migration[8.1]
  def change
    create_table :item_vendas do |t|
      t.references :venda,   null: false, foreign_key: true
      t.references :produto, null: false, foreign_key: true
      t.integer :quantidade,     null: false
      t.decimal :preco_unitario, precision: 10, scale: 2, null: false

      t.timestamps
    end
  end
end