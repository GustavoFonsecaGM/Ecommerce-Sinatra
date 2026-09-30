class Venda < ActiveRecord::Base
  class ErroDeCompra < StandardError; end

  STATUS = %w[pendente paga enviada entregue cancelada].freeze
  FLUXO  = { 'pendente' => 'paga', 'paga' => 'enviada', 'enviada' => 'entregue' }.freeze

  belongs_to :comprador, class_name: 'Usuario'
  belongs_to :vendedor,  class_name: 'Usuario'
  has_many :item_vendas, dependent: :destroy
  has_many :produtos, through: :item_vendas

  validates :data, presence: true
  validates :status, inclusion: { in: STATUS }
  validates :valor_total, numericality: { greater_than_or_equal_to: 0 }
  validate  :comprador_diferente_do_vendedor

  def self.registrar_compra!(comprador:, carrinho:)
    raise ErroDeCompra, 'Carrinho vazio' if carrinho.empty?

    vendas = []
    transaction do
      produtos = Produto.where(id: carrinho.keys.map(&:to_i)).to_a
      raise ErroDeCompra, 'Produto indisponível' if produtos.size != carrinho.size

      produtos.group_by(&:vendedor_id).each do |vendedor_id, lista|
        raise ErroDeCompra, 'Você não pode comprar o próprio produto' if vendedor_id == comprador.id

        venda = Venda.new(comprador: comprador, vendedor_id: vendedor_id,
                          data: Date.today, status: 'pendente', valor_total: 0)
        total = 0
        lista.each do |produto|
          quantidade = carrinho[produto.id.to_s].to_i
          if produto.estoque < quantidade
            raise ErroDeCompra, "Estoque insuficiente para #{produto.nome}"
          end

          venda.item_vendas.build(produto: produto, quantidade: quantidade,
                                  preco_unitario: produto.preco)
          produto.update!(estoque: produto.estoque - quantidade)
          total += produto.preco * quantidade
        end
        venda.valor_total = total
        venda.save!
        vendas << venda
      end
    end
    vendas
  end

  def cancelar!
    unless status == 'pendente'
      raise ErroDeCompra, "Só é possível cancelar uma compra pendente (esta está \"#{status}\")"
    end

    transaction do
      item_vendas.each do |item|
        produto = item.produto
        produto.update!(estoque: produto.estoque + item.quantidade)
      end
      update!(status: 'cancelada')
    end
    self
  end

  def avancar_status!
    proximo = FLUXO[status]
    raise ErroDeCompra, "Não há próxima situação depois de \"#{status}\"" if proximo.nil?

    update!(status: proximo)
    self
  end

  private

  def comprador_diferente_do_vendedor
    return if comprador_id.blank? || vendedor_id.blank?
    return if comprador_id != vendedor_id

    errors.add(:comprador_id, 'não pode ser o mesmo usuário que o vendedor')
  end
end