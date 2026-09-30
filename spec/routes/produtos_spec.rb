require 'spec_helper'

RSpec.describe 'Rotas de produto', type: :request do
  let(:vendedor) { cria_usuario }

  def dados_validos
    { nome: 'Caneca', descricao: 'de porcelana', preco: '19.90', estoque: '5' }
  end

  describe 'GET /produtos' do
    it 'responde 200 para visitante deslogado' do
      cria_produto(vendedor: vendedor, nome: 'Caneca')

      get '/produtos'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Caneca')
    end

    it 'filtra pela busca ?q=' do
      cria_produto(vendedor: vendedor, nome: 'Caneca')
      cria_produto(vendedor: vendedor, nome: 'Copo')

      get '/produtos', q: 'Cane'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Caneca')
      expect(last_response.body).not_to include('Copo')
    end
  end

  describe 'GET /produtos/novo' do
    it 'exige login' do
      get '/produtos/novo'

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/login')
    end

    it 'nao e confundida com /produtos/:id' do
      loga(vendedor)

      get '/produtos/novo'

      expect(last_response.status).to eq(200)
    end
  end

  describe 'GET /produtos/:id' do
    it 'responde 200 para visitante' do
      produto = cria_produto(vendedor: vendedor, nome: 'Caneca')

      get "/produtos/#{produto.id}"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Caneca')
    end

    it 'redireciona quando o produto nao existe' do
      get '/produtos/999999'

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/produtos')
    end
  end

  describe 'POST /produtos' do
    it 'cria o produto do vendedor logado e redireciona' do
      loga(vendedor)

      expect { post '/produtos', dados_validos }.to change(Produto, :count).by(1)

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/meus-produtos')
      expect(Produto.last.vendedor_id).to eq(vendedor.id)
    end

    it 'exige login' do
      expect { post '/produtos', dados_validos }.not_to change(Produto, :count)

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/login')
    end

    it 'recusa preco zero' do
      loga(vendedor)

      expect { post '/produtos', dados_validos.merge(preco: '0') }
        .not_to change(Produto, :count)

      expect(last_response.status).to eq(200)
    end

    it 'recusa estoque negativo' do
      loga(vendedor)

      expect { post '/produtos', dados_validos.merge(estoque: '-1') }
        .not_to change(Produto, :count)

      expect(last_response.status).to eq(200)
    end
  end

  describe 'GET /produtos/:id/editar' do
    it 'abre para o dono' do
      produto = cria_produto(vendedor: vendedor)
      loga(vendedor)

      get "/produtos/#{produto.id}/editar"

      expect(last_response.status).to eq(200)
    end

    it 'bloqueia produto de outro dono' do
      produto = cria_produto(vendedor: cria_usuario)
      loga(vendedor)

      get "/produtos/#{produto.id}/editar"

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/meus-produtos')
    end

    it 'exige login' do
      produto = cria_produto(vendedor: vendedor)

      get "/produtos/#{produto.id}/editar"

      expect(last_response.location).to end_with('/login')
    end
  end

  describe 'POST /produtos/:id' do
    it 'atualiza o produto do dono' do
      produto = cria_produto(vendedor: vendedor, nome: 'Caneca')
      loga(vendedor)

      post "/produtos/#{produto.id}", dados_validos.merge(nome: 'Caneca nova')

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/meus-produtos')
      expect(produto.reload.nome).to eq('Caneca nova')
    end

    it 'nao deixa editar produto de outro dono' do
      produto = cria_produto(vendedor: cria_usuario, nome: 'Caneca')
      loga(vendedor)

      post "/produtos/#{produto.id}", dados_validos.merge(nome: 'Invadida')

      expect(last_response.location).to end_with('/meus-produtos')
      expect(produto.reload.nome).to eq('Caneca')
    end

    it 'recusa dados invalidos com 200 e nao grava' do
      produto = cria_produto(vendedor: vendedor, nome: 'Caneca')
      loga(vendedor)

      post "/produtos/#{produto.id}", dados_validos.merge(nome: '')

      expect(last_response.status).to eq(200)
      expect(produto.reload.nome).to eq('Caneca')
    end
  end

  describe 'POST /produtos/:id/excluir' do
    it 'exclui produto que nunca foi vendido' do
      produto = cria_produto(vendedor: vendedor)
      loga(vendedor)

      expect { post "/produtos/#{produto.id}/excluir" }.to change(Produto, :count).by(-1)

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/meus-produtos')
    end

    it 'bloqueia a exclusao de produto ja vendido' do
      produto = cria_produto(vendedor: vendedor)
      venda   = cria_venda(comprador: cria_usuario, vendedor: vendedor)
      cria_item(venda: venda, produto: produto)
      loga(vendedor)

      expect { post "/produtos/#{produto.id}/excluir" }.not_to change(Produto, :count)

      expect(last_response.location).to end_with('/meus-produtos')
    end

    it 'nao deixa excluir produto de outro dono' do
      produto = cria_produto(vendedor: cria_usuario)
      loga(vendedor)

      expect { post "/produtos/#{produto.id}/excluir" }.not_to change(Produto, :count)
    end

    it 'exige login' do
      produto = cria_produto(vendedor: vendedor)

      expect { post "/produtos/#{produto.id}/excluir" }.not_to change(Produto, :count)

      expect(last_response.location).to end_with('/login')
    end
  end

  describe 'GET /meus-produtos' do
    it 'lista so os produtos do logado' do
      cria_produto(vendedor: vendedor,      nome: 'Minha caneca')
      cria_produto(vendedor: cria_usuario,  nome: 'Caneca alheia')
      loga(vendedor)

      get '/meus-produtos'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Minha caneca')
      expect(last_response.body).not_to include('Caneca alheia')
    end

    it 'exige login' do
      get '/meus-produtos'

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/login')
    end
  end
end