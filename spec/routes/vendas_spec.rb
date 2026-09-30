require 'spec_helper'

RSpec.describe 'Rotas de vendas do vendedor', type: :request do
  let(:vendedor)  { cria_usuario }
  let(:comprador) { cria_usuario }
  let(:produto)   { cria_produto(vendedor: vendedor, preco: '19.90', estoque: 10) }

  def venda_pendente
    Venda.registrar_compra!(comprador: comprador, carrinho: { produto.id.to_s => 1 }).first
  end

  describe 'GET /vendas-recebidas' do
    it 'exige login' do
      get '/vendas-recebidas'

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/login')
    end

    it 'lista as vendas do vendedor logado' do
      venda = venda_pendente
      loga(vendedor)

      get '/vendas-recebidas'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("Venda ##{venda.id}")
    end

    it 'nao mostra a venda para o comprador' do
      venda = venda_pendente
      loga(comprador)

      get '/vendas-recebidas'

      expect(last_response.status).to eq(200)
      expect(last_response.body).not_to include("Venda ##{venda.id}")
    end
  end

  describe 'POST /vendas/:id/avancar' do
    it 'segue o fluxo natural ate a entrega' do
      venda = venda_pendente
      loga(vendedor)

      post "/vendas/#{venda.id}/avancar"
      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/vendas-recebidas')
      expect(venda.reload.status).to eq('paga')

      post "/vendas/#{venda.id}/avancar"
      expect(venda.reload.status).to eq('enviada')

      post "/vendas/#{venda.id}/avancar"
      expect(venda.reload.status).to eq('entregue')
    end

    it 'nao avanca depois de entregue' do
      venda = venda_pendente
      3.times { venda.avancar_status! }
      loga(vendedor)

      post "/vendas/#{venda.id}/avancar"

      expect(last_response.status).to eq(302)
      expect(venda.reload.status).to eq('entregue')
    end

    it 'nao deixa o comprador avancar a venda' do
      venda = venda_pendente
      loga(comprador)

      post "/vendas/#{venda.id}/avancar"

      expect(last_response.location).to end_with('/vendas-recebidas')
      expect(venda.reload.status).to eq('pendente')
    end

    it 'exige login' do
      venda = venda_pendente

      post "/vendas/#{venda.id}/avancar"

      expect(last_response.location).to end_with('/login')
      expect(venda.reload.status).to eq('pendente')
    end
  end
end