require 'spec_helper'

RSpec.describe 'Rotas de cadastro, sessao e perfil', type: :request do
  def dados_validos(email: 'ana@exemplo.com')
    { nome: 'Ana', email: email, cpf: '11122233344',
      telefone: '62999990000', senha: 'segredo123' }
  end

  describe 'GET /' do
    it 'redireciona para /produtos' do
      get '/'

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/produtos')
    end
  end

  describe 'GET /cadastro' do
    it 'responde 200' do
      get '/cadastro'

      expect(last_response.status).to eq(200)
    end
  end

  describe 'POST /usuarios' do
    it 'cria o usuario, ja deixa logado e redireciona para /produtos' do
      expect { post '/usuarios', dados_validos }.to change(Usuario, :count).by(1)

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/produtos')

      get '/meus-produtos' # rota protegida: 200 prova que a sessao foi criada
      expect(last_response.status).to eq(200)
    end

    it 'recusa email repetido sem criar registro' do
      cria_usuario(email: 'ana@exemplo.com')

      expect { post '/usuarios', dados_validos }.not_to change(Usuario, :count)
      expect(last_response.status).to eq(200) # re-renderiza o formulario
    end

    it 'recusa email com formato invalido' do
      expect { post '/usuarios', dados_validos(email: 'nao-e-email') }
        .not_to change(Usuario, :count)

      expect(last_response.status).to eq(200)
    end

    it 'recusa cadastro sem senha' do
      expect { post '/usuarios', dados_validos.merge(senha: '') }
        .not_to change(Usuario, :count)

      expect(last_response.status).to eq(200)
    end
  end

  describe 'GET /login' do
    it 'responde 200' do
      get '/login'

      expect(last_response.status).to eq(200)
    end
  end

  describe 'POST /login' do
    it 'autentica e redireciona para /produtos' do
      cria_usuario(email: 'ana@exemplo.com')

      post '/login', email: 'ana@exemplo.com', senha: 'segredo123'

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/produtos')
    end

    it 'recusa senha errada e nao abre sessao' do
      cria_usuario(email: 'ana@exemplo.com')

      post '/login', email: 'ana@exemplo.com', senha: 'errada'
      expect(last_response.status).to eq(200)

      get '/meus-produtos'
      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/login')
    end

    it 'recusa email inexistente' do
      post '/login', email: 'ninguem@exemplo.com', senha: 'segredo123'

      expect(last_response.status).to eq(200)
    end
  end

  describe 'POST /logout' do
    it 'encerra a sessao' do
      loga(cria_usuario)

      post '/logout'
      expect(last_response.status).to eq(302)

      get '/meus-produtos'
      expect(last_response.location).to end_with('/login')
    end
  end

  describe 'GET /perfil/editar' do
    it 'exige login' do
      get '/perfil/editar'

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/login')
    end

    it 'responde 200 para quem esta logado' do
      loga(cria_usuario)

      get '/perfil/editar'

      expect(last_response.status).to eq(200)
    end
  end

  describe 'POST /perfil' do
    it 'atualiza os dados e redireciona' do
      usuario = cria_usuario(nome: 'Ana')
      loga(usuario)

      post '/perfil', nome: 'Ana Maria', email: usuario.email,
                      cpf: usuario.cpf, telefone: '6230000000', senha: ''

      expect(last_response.status).to eq(302)
      expect(usuario.reload.nome).to eq('Ana Maria')
    end

    it 'mantem a senha atual quando o campo vem em branco' do
      usuario = cria_usuario
      hash_antigo = usuario.senha_hash
      loga(usuario)

      post '/perfil', nome: usuario.nome, email: usuario.email,
                      cpf: usuario.cpf, telefone: '', senha: ''

      expect(usuario.reload.senha_hash).to eq(hash_antigo)
    end

    it 'troca a senha quando o campo vem preenchido' do
      usuario = cria_usuario
      loga(usuario)

      post '/perfil', nome: usuario.nome, email: usuario.email,
                      cpf: usuario.cpf, telefone: '', senha: 'outrasenha'

      expect(usuario.reload.autentica('outrasenha')).to be(true)
    end

    it 'exige login' do
      post '/perfil', nome: 'X'

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/login')
    end
  end
end