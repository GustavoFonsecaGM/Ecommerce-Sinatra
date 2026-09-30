require 'spec_helper'

RSpec.describe 'Rotas de compras do comprador', type: :request do
  let(:vendedor)  { cria_usuario }
  let(:comprador) { cria_usuario }
  let(:produto)   { cria_produto(vendedor: vendedor, preco: '19.90', estoque: 10) }

  def compra_pendente
    Venda.registrar_compra!(comprador: comprador, carrinho: { produto.id.to_s => 2 }).first
  end

  describe 'GET /minhas-compras' do
    it 'exige login' do
      get '/minhas-compras'

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/login')
    end

    it 'lista as compras do logado' do
      venda = compra_pendente
      loga(comprador)

      get '/minhas-compras'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("Compra ##{venda.id}")
    end

    it 'nao mostra a compra de outro usuario' do
      venda = compra_pendente
      loga(cria_usuario)

      get '/minhas-compras'

      expect(last_response.status).to eq(200)
      expect(last_response.body).not_to include("Compra ##{venda.id}")
    end
  end

  describe 'POST /compras/:id/cancelar' do
    it 'cancela e estorna o estoque' do
      venda = compra_pendente
      expect(produto.reload.estoque).to eq(8)
      loga(comprador)

      post "/compras/#{venda.id}/cancelar"

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/minhas-compras')
      expect(venda.reload.status).to eq('cancelada')
      expect(produto.reload.estoque).to eq(10)
    end

    it 'nao cancela compra de outro comprador' do
      venda = compra_pendente
      loga(cria_usuario)

      post "/compras/#{venda.id}/cancelar"

      expect(last_response.location).to end_with('/minhas-compras')
      expect(venda.reload.status).to eq('pendente')
      expect(produto.reload.estoque).to eq(8)
    end

    it 'nao cancela compra que ja saiu de pendente' do
      venda = compra_pendente
      venda.avancar_status! # pendente -> paga
      loga(comprador)

      post "/compras/#{venda.id}/cancelar"

      expect(last_response.status).to eq(302)
      expect(venda.reload.status).to eq('paga')
      expect(produto.reload.estoque).to eq(8) # nao estornou
    end

    it 'exige login' do
      venda = compra_pendente

      post "/compras/#{venda.id}/cancelar"

      expect(last_response.location).to end_with('/login')
      expect(venda.reload.status).to eq('pendente')
    end
  end
end