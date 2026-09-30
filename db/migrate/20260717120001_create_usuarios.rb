class CreateUsuarios < ActiveRecord::Migration[8.1]
  def change
    create_table :usuarios do |t|
      t.string :nome,       null: false
      t.string :email,      null: false
      t.string :senha_hash, null: false
      t.string :cpf,        null: false
      t.string :telefone

      t.timestamps
    end

    add_index :usuarios, :email, unique: true
  end
end