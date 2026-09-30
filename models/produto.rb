class Produto < ActiveRecord::Base
  belongs_to :vendedor, class_name: 'Usuario'
  has_many :item_vendas, dependent: :restrict_with_error

  validates :nome, presence: true
  validates :preco, numericality: { greater_than: 0 }
  validates :estoque, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end