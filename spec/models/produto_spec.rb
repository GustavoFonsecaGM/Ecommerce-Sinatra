require 'spec_helper'

RSpec.describe Produto do
  let(:vendedor) { cria_usuario }

  describe 'atributos' do
    it 'persiste nome, descricao, preco e estoque' do
      produto = cria_produto(vendedor: vendedor, nome: 'Caneca',
                             descricao: 'de porcelana', preco: '19.90', estoque: 5)
      produto.reload

      expect(produto.nome).to eq('Caneca')
      expect(produto.descricao).to eq('de porcelana')
      expect(produto.preco).to eq(BigDecimal('19.90'))
      expect(produto.estoque).to eq(5)
    end
  end

  describe 'associações' do
    it 'pertence a um vendedor' do
      produto = cria_produto(vendedor: vendedor)

      expect(produto.vendedor).to eq(vendedor)
      expect(produto.vendedor_id).to eq(vendedor.id)
    end

    it 'tem muitos item_vendas' do
      produto   = cria_produto(vendedor: vendedor)
      comprador = cria_usuario
      venda     = cria_venda(comprador: comprador, vendedor: vendedor)
      cria_item(venda: venda, produto: produto)

      expect(produto.item_vendas.count).to eq(1)
    end

    it 'bloqueia a exclusao de produto ja vendido, com mensagem de erro' do
      produto   = cria_produto(vendedor: vendedor)
      comprador = cria_usuario
      venda     = cria_venda(comprador: comprador, vendedor: vendedor)
      cria_item(venda: venda, produto: produto)

      expect(produto.destroy).to be(false)
      expect(produto.errors[:base]).not_to be_empty
      expect(Produto.exists?(produto.id)).to be(true)
    end

    it 'permite excluir produto que nunca foi vendido' do
      produto = cria_produto(vendedor: vendedor)

      expect(produto.destroy).to be_truthy
      expect(Produto.exists?(produto.id)).to be(false)
    end
  end

  describe 'validações' do
    it 'exige nome' do
      produto = Produto.new(preco: 10, estoque: 1, vendedor: vendedor)

      expect(produto).not_to be_valid
      expect(produto.errors[:nome]).not_to be_empty
    end

    it 'exige vendedor' do
      produto = Produto.new(nome: 'X', preco: 10, estoque: 1)

      expect(produto).not_to be_valid
      expect(produto.errors[:vendedor]).not_to be_empty
    end

    it 'rejeita preco zero ou negativo' do
      [0, -1].each do |preco|
        produto = Produto.new(nome: 'X', preco: preco, estoque: 1, vendedor: vendedor)

        expect(produto).not_to be_valid
        expect(produto.errors[:preco]).not_to be_empty
      end
    end

    it 'rejeita estoque negativo mas aceita zero' do
      negativo = Produto.new(nome: 'X', preco: 10, estoque: -1, vendedor: vendedor)
      zerado   = Produto.new(nome: 'X', preco: 10, estoque: 0,  vendedor: vendedor)

      expect(negativo).not_to be_valid
      expect(negativo.errors[:estoque]).not_to be_empty
      expect(zerado).to be_valid
    end

    it 'rejeita estoque fracionado' do
      produto = Produto.new(nome: 'X', preco: 10, estoque: 1.5, vendedor: vendedor)

      expect(produto).not_to be_valid
      expect(produto.errors[:estoque]).not_to be_empty
    end
  end
end