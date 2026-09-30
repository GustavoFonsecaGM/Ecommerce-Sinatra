require 'spec_helper'

RSpec.describe ItemVenda do
  let(:vendedor)  { cria_usuario }
  let(:comprador) { cria_usuario }
  let(:produto)   { cria_produto(vendedor: vendedor, preco: '19.90') }
  let(:venda)     { cria_venda(comprador: comprador, vendedor: vendedor) }

  describe 'atributos' do
    it 'persiste quantidade e preco_unitario' do
      item = cria_item(venda: venda, produto: produto, quantidade: 3, preco_unitario: '19.90')
      item.reload

      expect(item.quantidade).to eq(3)
      expect(item.preco_unitario).to eq(BigDecimal('19.90'))
    end

    it 'congela o preco praticado, mesmo se o produto mudar de preco depois' do
      item = cria_item(venda: venda, produto: produto, preco_unitario: produto.preco)
      produto.update!(preco: '99.90')

      expect(item.reload.preco_unitario).to eq(BigDecimal('19.90'))
      expect(item.produto.preco).to eq(BigDecimal('99.90'))
    end
  end

  describe 'associações' do
    it 'pertence a uma venda e a um produto' do
      item = cria_item(venda: venda, produto: produto)

      expect(item.venda).to eq(venda)
      expect(item.produto).to eq(produto)
    end
  end

  describe 'validações' do
    it 'exige venda e produto' do
      item = ItemVenda.new(quantidade: 1, preco_unitario: 10)

      expect(item).not_to be_valid
      expect(item.errors[:venda]).not_to be_empty
      expect(item.errors[:produto]).not_to be_empty
    end

    it 'rejeita quantidade zero ou negativa' do
      [0, -2].each do |quantidade|
        item = ItemVenda.new(venda: venda, produto: produto,
                             quantidade: quantidade, preco_unitario: 10)

        expect(item).not_to be_valid
        expect(item.errors[:quantidade]).not_to be_empty
      end
    end

    it 'rejeita quantidade fracionada' do
      item = ItemVenda.new(venda: venda, produto: produto,
                           quantidade: 1.5, preco_unitario: 10)

      expect(item).not_to be_valid
      expect(item.errors[:quantidade]).not_to be_empty
    end

    it 'rejeita preco_unitario zero ou negativo' do
      item = ItemVenda.new(venda: venda, produto: produto,
                           quantidade: 1, preco_unitario: 0)

      expect(item).not_to be_valid
      expect(item.errors[:preco_unitario]).not_to be_empty
    end

    it 'aceita um item completo' do
      expect(ItemVenda.new(venda: venda, produto: produto,
                           quantidade: 2, preco_unitario: '19.90')).to be_valid
    end
  end
end