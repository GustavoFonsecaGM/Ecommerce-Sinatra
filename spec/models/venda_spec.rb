require 'spec_helper'

RSpec.describe Venda do
  let(:vendedor)  { cria_usuario }
  let(:comprador) { cria_usuario }

  describe 'atributos' do
    it 'persiste data, status e valor_total' do
      venda = cria_venda(comprador: comprador, vendedor: vendedor,
                         status: 'paga', valor_total: '39.80')
      venda.reload

      expect(venda.data).to eq(Date.today)
      expect(venda.status).to eq('paga')
      expect(venda.valor_total).to eq(BigDecimal('39.80'))
    end

    it 'nasce pendente por padrao' do
      venda = Venda.create!(comprador: comprador, vendedor: vendedor, data: Date.today)

      expect(venda.reload.status).to eq('pendente')
    end
  end

  describe 'constantes' do
    it 'define os cinco status do enunciado' do
      expect(Venda::STATUS).to eq(%w[pendente paga enviada entregue cancelada])
    end

    it 'define o fluxo natural ate a entrega' do
      expect(Venda::FLUXO).to eq('pendente' => 'paga', 'paga' => 'enviada', 'enviada' => 'entregue')
    end
  end

  describe 'associações' do
    it 'pertence a um comprador e a um vendedor' do
      venda = cria_venda(comprador: comprador, vendedor: vendedor)

      expect(venda.comprador).to eq(comprador)
      expect(venda.vendedor).to eq(vendedor)
    end

    it 'tem muitos item_vendas e alcanca os produtos through' do
      venda = cria_venda(comprador: comprador, vendedor: vendedor)
      caneca = cria_produto(vendedor: vendedor, nome: 'Caneca')
      copo   = cria_produto(vendedor: vendedor, nome: 'Copo')
      cria_item(venda: venda, produto: caneca)
      cria_item(venda: venda, produto: copo)

      expect(venda.item_vendas.count).to eq(2)
      expect(venda.produtos).to contain_exactly(caneca, copo)
    end

    it 'destroi os itens junto com a venda' do
      venda   = cria_venda(comprador: comprador, vendedor: vendedor)
      produto = cria_produto(vendedor: vendedor)
      cria_item(venda: venda, produto: produto)

      expect { venda.destroy }.to change(ItemVenda, :count).by(-1)
    end
  end

  describe '.registrar_compra!' do
    it 'debita o estoque e calcula o valor_total automaticamente' do
      produto = cria_produto(vendedor: vendedor, preco: '19.90', estoque: 10)

      vendas = Venda.registrar_compra!(comprador: comprador, carrinho: { produto.id.to_s => 3 })

      expect(vendas.size).to eq(1)
      expect(vendas.first.valor_total).to eq(BigDecimal('59.70'))
      expect(vendas.first.status).to eq('pendente')
      expect(produto.reload.estoque).to eq(7)
    end

    it 'copia o preco do produto para o item no instante da compra' do
      produto = cria_produto(vendedor: vendedor, preco: '19.90', estoque: 5)

      venda = Venda.registrar_compra!(comprador: comprador, carrinho: { produto.id.to_s => 1 }).first

      expect(venda.item_vendas.first.preco_unitario).to eq(BigDecimal('19.90'))
    end

    it 'cria uma venda por vendedor quando o carrinho mistura vendedores' do
      outro_vendedor = cria_usuario
      caneca = cria_produto(vendedor: vendedor,       preco: '10.00', estoque: 5)
      copo   = cria_produto(vendedor: outro_vendedor, preco: '20.00', estoque: 5)

      vendas = Venda.registrar_compra!(comprador: comprador,
                                       carrinho: { caneca.id.to_s => 1, copo.id.to_s => 2 })

      expect(vendas.size).to eq(2)
      expect(vendas.map(&:vendedor_id)).to contain_exactly(vendedor.id, outro_vendedor.id)
      expect(vendas.sum(&:valor_total)).to eq(BigDecimal('50.00'))
    end

    it 'recusa carrinho vazio' do
      expect { Venda.registrar_compra!(comprador: comprador, carrinho: {}) }
        .to raise_error(Venda::ErroDeCompra, /vazio/i)
    end

    it 'recusa comprar o proprio produto' do
      proprio = cria_produto(vendedor: comprador)

      expect { Venda.registrar_compra!(comprador: comprador, carrinho: { proprio.id.to_s => 1 }) }
        .to raise_error(Venda::ErroDeCompra)
    end

    it 'recusa produto inexistente' do
      expect { Venda.registrar_compra!(comprador: comprador, carrinho: { '999999' => 1 }) }
        .to raise_error(Venda::ErroDeCompra)
    end

    it 'falha a transacao INTEIRA quando falta estoque em um dos itens' do
      ok    = cria_produto(vendedor: vendedor, nome: 'Com estoque', preco: '10.00', estoque: 5)
      falta = cria_produto(vendedor: vendedor, nome: 'Sem estoque', preco: '10.00', estoque: 1)

      expect {
        Venda.registrar_compra!(comprador: comprador,
                                carrinho: { ok.id.to_s => 1, falta.id.to_s => 99 })
      }.to raise_error(Venda::ErroDeCompra, /Estoque insuficiente/)

      expect(Venda.count).to eq(0)
      expect(ItemVenda.count).to eq(0)
      expect(ok.reload.estoque).to eq(5)
      expect(falta.reload.estoque).to eq(1)
    end
  end

  describe '#cancelar!' do
    it 'estorna o estoque e marca como cancelada' do
      produto = cria_produto(vendedor: vendedor, estoque: 10)
      venda = Venda.registrar_compra!(comprador: comprador, carrinho: { produto.id.to_s => 3 }).first
      expect(produto.reload.estoque).to eq(7)

      venda.cancelar!

      expect(venda.reload.status).to eq('cancelada')
      expect(produto.reload.estoque).to eq(10)
    end

    it 'recusa cancelar compra que nao esta pendente' do
      venda = cria_venda(comprador: comprador, vendedor: vendedor, status: 'paga')

      expect { venda.cancelar! }.to raise_error(Venda::ErroDeCompra)
      expect(venda.reload.status).to eq('paga')
    end
  end

  describe '#avancar_status!' do
    it 'segue o fluxo natural ate a entrega' do
      venda = cria_venda(comprador: comprador, vendedor: vendedor)

      expect(venda.avancar_status!.status).to eq('paga')
      expect(venda.avancar_status!.status).to eq('enviada')
      expect(venda.avancar_status!.status).to eq('entregue')
    end

    it 'nao avanca depois de entregue' do
      venda = cria_venda(comprador: comprador, vendedor: vendedor, status: 'entregue')

      expect { venda.avancar_status! }.to raise_error(Venda::ErroDeCompra)
    end

    it 'nao avanca uma venda cancelada' do
      venda = cria_venda(comprador: comprador, vendedor: vendedor, status: 'cancelada')

      expect { venda.avancar_status! }.to raise_error(Venda::ErroDeCompra)
    end
  end

  describe 'validações' do
    it 'exige data' do
      venda = Venda.new(comprador: comprador, vendedor: vendedor, status: 'pendente')

      expect(venda).not_to be_valid
      expect(venda.errors[:data]).not_to be_empty
    end

    it 'exige comprador e vendedor' do
      venda = Venda.new(data: Date.today)

      expect(venda).not_to be_valid
      expect(venda.errors[:comprador]).not_to be_empty
      expect(venda.errors[:vendedor]).not_to be_empty
    end

    it 'aceita apenas os cinco status previstos' do
      Venda::STATUS.each do |status|
        venda = Venda.new(comprador: comprador, vendedor: vendedor,
                          data: Date.today, status: status)
        expect(venda).to be_valid
      end
    end

    it 'rejeita status fora do conjunto' do
      venda = Venda.new(comprador: comprador, vendedor: vendedor,
                        data: Date.today, status: 'devolvida')

      expect(venda).not_to be_valid
      expect(venda.errors[:status]).not_to be_empty
    end

    it 'exige comprador e vendedor distintos' do
      venda = Venda.new(comprador: comprador, vendedor: comprador, data: Date.today)

      expect(venda).not_to be_valid
      expect(venda.errors[:comprador_id]).not_to be_empty
    end

    it 'rejeita valor_total negativo' do
      venda = Venda.new(comprador: comprador, vendedor: vendedor,
                        data: Date.today, valor_total: -1)

      expect(venda).not_to be_valid
      expect(venda.errors[:valor_total]).not_to be_empty
    end
  end
end