require 'spec_helper'

RSpec.describe 'Rotas de carrinho', type: :request do
  let(:vendedor)  { cria_usuario }
  let(:comprador) { cria_usuario }
  let(:produto)   { cria_produto(vendedor: vendedor, nome: 'Caneca', preco: '19.90', estoque: 10) }

  describe 'POST /carrinho/itens' do
    it 'aceita visitante deslogado e leva para o carrinho' do
      post '/carrinho/itens', produto_id: produto.id, quantidade: 2

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/carrinho')

      get '/carrinho'
      expect(last_response.body).to include('Caneca')
    end

    it 'soma quantidade quando o mesmo produto e adicionado de novo' do
      post '/carrinho/itens', produto_id: produto.id, quantidade: 2
      post '/carrinho/itens', produto_id: produto.id, quantidade: 3
      loga(comprador)

      post '/carrinho/finalizar'

      expect(Venda.last.item_vendas.first.quantidade).to eq(5)
    end

    it 'recusa o proprio produto do vendedor logado' do
      loga(vendedor)

      post '/carrinho/itens', produto_id: produto.id, quantidade: 1

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with("/produtos/#{produto.id}")
    end

    it 'recusa quantidade zero' do
      post '/carrinho/itens', produto_id: produto.id, quantidade: 0

      expect(last_response.location).to end_with("/produtos/#{produto.id}")
    end

    it 'redireciona quando o produto nao existe' do
      post '/carrinho/itens', produto_id: 999999, quantidade: 1

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/produtos')
    end
  end

  describe 'GET /carrinho' do
    it 'responde 200 mesmo vazio e deslogado' do
      get '/carrinho'

      expect(last_response.status).to eq(200)
    end
  end

  describe 'POST /carrinho/itens/:produto_id/remover' do
    it 'tira o item do carrinho' do
      post '/carrinho/itens', produto_id: produto.id, quantidade: 1

      post "/carrinho/itens/#{produto.id}/remover"
      expect(last_response.location).to end_with('/carrinho')

      get '/carrinho'
      expect(last_response.body).not_to include('Caneca')
    end
  end

  describe 'POST /carrinho/finalizar' do
    it 'exige login' do
      post '/carrinho/itens', produto_id: produto.id, quantidade: 1

      expect { post '/carrinho/finalizar' }.not_to change(Venda, :count)

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/login')
    end

    it 'cria a venda, debita o estoque e esvazia o carrinho' do
      post '/carrinho/itens', produto_id: produto.id, quantidade: 3
      loga(comprador)

      expect { post '/carrinho/finalizar' }.to change(Venda, :count).by(1)

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/minhas-compras')
      expect(produto.reload.estoque).to eq(7)

      get '/carrinho'
      expect(last_response.body).not_to include('Caneca')
    end

    it 'recusa carrinho vazio' do
      loga(comprador)

      expect { post '/carrinho/finalizar' }.not_to change(Venda, :count)

      expect(last_response.location).to end_with('/carrinho')
    end

    it 'recusa estoque insuficiente sem criar venda nem mexer no estoque' do
      post '/carrinho/itens', produto_id: produto.id, quantidade: 99
      loga(comprador)

      expect { post '/carrinho/finalizar' }.not_to change(Venda, :count)

      expect(last_response.location).to end_with('/carrinho')
      expect(produto.reload.estoque).to eq(10)
    end

    it 'recusa comprar o proprio produto entrando no carrinho deslogado' do
      post '/carrinho/itens', produto_id: produto.id, quantidade: 1
      loga(vendedor) # o dono loga depois de ja ter o item no carrinho

      expect { post '/carrinho/finalizar' }.not_to change(Venda, :count)

      expect(last_response.location).to end_with('/carrinho')
    end
  end
end