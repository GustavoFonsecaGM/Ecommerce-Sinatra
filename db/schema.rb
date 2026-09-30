# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_17_120004) do
  create_table "item_vendas", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "preco_unitario", precision: 10, scale: 2, null: false
    t.integer "produto_id", null: false
    t.integer "quantidade", null: false
    t.datetime "updated_at", null: false
    t.integer "venda_id", null: false
    t.index ["produto_id"], name: "index_item_vendas_on_produto_id"
    t.index ["venda_id"], name: "index_item_vendas_on_venda_id"
  end

  create_table "produtos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "descricao"
    t.integer "estoque", default: 0, null: false
    t.string "nome", null: false
    t.decimal "preco", precision: 10, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.integer "vendedor_id", null: false
    t.index ["vendedor_id"], name: "index_produtos_on_vendedor_id"
  end

  create_table "usuarios", force: :cascade do |t|
    t.string "cpf", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "nome", null: false
    t.string "senha_hash", null: false
    t.string "telefone"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_usuarios_on_email", unique: true
  end

  create_table "vendas", force: :cascade do |t|
    t.integer "comprador_id", null: false
    t.datetime "created_at", null: false
    t.date "data", null: false
    t.string "status", default: "pendente", null: false
    t.datetime "updated_at", null: false
    t.decimal "valor_total", precision: 10, scale: 2, default: "0.0", null: false
    t.integer "vendedor_id", null: false
    t.index ["comprador_id"], name: "index_vendas_on_comprador_id"
    t.index ["vendedor_id"], name: "index_vendas_on_vendedor_id"
  end

  add_foreign_key "item_vendas", "produtos"
  add_foreign_key "item_vendas", "vendas"
  add_foreign_key "produtos", "usuarios", column: "vendedor_id"
  add_foreign_key "vendas", "usuarios", column: "comprador_id"
  add_foreign_key "vendas", "usuarios", column: "vendedor_id"
end
