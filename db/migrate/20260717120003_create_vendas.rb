class CreateVendas < ActiveRecord::Migration[8.1]
  def change
    create_table :vendas do |t|
      t.references :comprador, null: false, foreign_key: { to_table: :usuarios }
      t.references :vendedor,  null: false, foreign_key: { to_table: :usuarios }
      t.date    :data,        null: false
      t.string  :status,      null: false, default: 'pendente'
      t.decimal :valor_total, precision: 10, scale: 2, null: false, default: 0

      t.timestamps
    end
  end
end