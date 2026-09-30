class ItemVenda < ActiveRecord::Base
  belongs_to :venda
  belongs_to :produto

  validates :quantidade, numericality: { only_integer: true, greater_than: 0 }
  validates :preco_unitario, numericality: { greater_than: 0 }
end