require 'sinatra/base'
require 'sinatra/activerecord'
require 'bcrypt'
require 'securerandom'
require 'uri'


ActiveRecord::Base.belongs_to_required_by_default = true

class App < Sinatra::Base
  register Sinatra::ActiveRecordExtension

  set :root, File.dirname(__FILE__)
  set :database_file, 'config/database.yml'
  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }
  set :method_override, false

  helpers do
    def usuario_atual
      @usuario_atual ||= Usuario.find_by(id: session[:usuario_id])
    end

    def logado?
      !usuario_atual.nil?
    end

    def requer_login!
      return if logado?
      erro('Faça login para continuar.')
      redirect '/login'
    end

    def sucesso(mensagem)
      session[:sucesso] = mensagem
    end

    def erro(mensagem)
      session[:erro] = mensagem
    end

    def mensagens_de(registro)
      registro.errors.full_messages.join('; ')
    end

    def produto_do_vendedor!(id)
      produto = usuario_atual.produtos.find_by(id: id)
      return produto if produto

      erro('Produto não encontrado ou não pertence a você.')
      redirect '/meus-produtos'
    end

    def dados_de_usuario
      { nome: params[:nome], email: params[:email], cpf: params[:cpf],
        telefone: params[:telefone], senha: params[:senha] }
    end

    def dados_de_produto
      { nome: params[:nome], descricao: params[:descricao],
        preco: params[:preco], estoque: params[:estoque] }
    end

    def carrinho
      session[:carrinho] ||= {}
    end

    def salva_carrinho!
      session[:carrinho] = carrinho.reject { |_id, quantidade| quantidade.to_i < 1 }
    end


    def itens_do_carrinho
      mapa = Produto.includes(:vendedor).where(id: carrinho.keys.map(&:to_i))
                    .each_with_object({}) { |produto, acc| acc[produto.id.to_s] = produto }

      carrinho.filter_map do |produto_id, quantidade|
        produto = mapa[produto_id]
        next if produto.nil?

        { produto: produto, quantidade: quantidade.to_i,
          subtotal: produto.preco * quantidade.to_i }
      end
    end

    def moeda(valor)
      format('R$ %.2f', valor).tr('.', ',')
    end

    def h(texto)
      Rack::Utils.escape_html(texto.to_s)
    end
  end

  get '/' do
    redirect '/produtos'
  end

  get '/cadastro' do
    @usuario = Usuario.new
    erb :'usuarios/novo'
  end

  post '/usuarios' do
    @usuario = Usuario.new(dados_de_usuario)
    if @usuario.save
      session[:usuario_id] = @usuario.id
      sucesso("Cadastro realizado. Bem-vindo(a), #{@usuario.nome}!")
      redirect '/produtos'
    else
      erro("Não foi possível cadastrar: #{mensagens_de(@usuario)}")
      erb :'usuarios/novo'
    end
  end

  get '/login' do
    erb :'sessoes/nova'
  end

  post '/login' do
    usuario = Usuario.find_by(email: params[:email].to_s.downcase.strip)
    if usuario&.autentica(params[:senha].to_s)
      session[:usuario_id] = usuario.id
      sucesso('Login realizado.')
      redirect '/produtos'
    else
      erro('E-mail ou senha inválidos.')
      erb :'sessoes/nova'
    end
  end

  post '/logout' do
    session.delete(:usuario_id)
    sucesso('Sessão encerrada.')
    redirect '/produtos'
  end

  get '/perfil/editar' do
    requer_login!
    @usuario = usuario_atual
    erb :'usuarios/editar'
  end

  post '/perfil' do
    requer_login!
    @usuario = usuario_atual
    if @usuario.update(dados_de_usuario)
      sucesso('Perfil atualizado.')
      redirect '/perfil/editar'
    else
      erro("Não foi possível salvar: #{mensagens_de(@usuario)}")
      erb :'usuarios/editar'
    end
  end

  get '/produtos' do
    @busca = params[:q].to_s.strip
    @produtos = Produto.includes(:vendedor).order(:nome)
    unless @busca.empty?
      curinga = "%#{@busca}%"
      @produtos = @produtos.where('nome LIKE ? OR descricao LIKE ?', curinga, curinga)
    end
    erb :'produtos/index'
  end


  get '/produtos/novo' do
    requer_login!
    @produto = Produto.new
    erb :'produtos/novo'
  end

  get '/produtos/:id' do
    @produto = Produto.find_by(id: params[:id])
    if @produto.nil?
      erro('Produto não encontrado.')
      redirect '/produtos'
    end
    erb :'produtos/show'
  end

  post '/produtos' do
    requer_login!
    @produto = usuario_atual.produtos.new(dados_de_produto)
    if @produto.save
      sucesso("Produto \"#{@produto.nome}\" cadastrado.")
      redirect '/meus-produtos'
    else
      erro("Não foi possível cadastrar: #{mensagens_de(@produto)}")
      erb :'produtos/novo'
    end
  end

  get '/produtos/:id/editar' do
    requer_login!
    @produto = produto_do_vendedor!(params[:id])
    erb :'produtos/editar'
  end

  post '/produtos/:id' do
    requer_login!
    @produto = produto_do_vendedor!(params[:id])
    if @produto.update(dados_de_produto)
      sucesso("Produto \"#{@produto.nome}\" atualizado.")
      redirect '/meus-produtos'
    else
      erro("Não foi possível salvar: #{mensagens_de(@produto)}")
      erb :'produtos/editar'
    end
  end

  post '/produtos/:id/excluir' do
    requer_login!
    produto = produto_do_vendedor!(params[:id])
    if produto.destroy
      sucesso("Produto \"#{produto.nome}\" excluído.")
    else
      erro("Não foi possível excluir: #{mensagens_de(produto)}")
    end
    redirect '/meus-produtos'
  end

  get '/meus-produtos' do
    requer_login!
    @produtos = usuario_atual.produtos.order(:nome)
    erb :'produtos/meus'
  end

  post '/carrinho/itens' do
    produto = Produto.find_by(id: params[:produto_id])
    if produto.nil?
      erro('Produto não encontrado.')
      redirect '/produtos'
    end

    quantidade = params[:quantidade].to_i
    if quantidade < 1
      erro('Informe uma quantidade maior que zero.')
      redirect "/produtos/#{produto.id}"
    end

    if logado? && produto.vendedor_id == usuario_atual.id
      erro('Você não pode comprar o próprio produto.')
      redirect "/produtos/#{produto.id}"
    end

    chave = produto.id.to_s
    carrinho[chave] = carrinho.fetch(chave, 0).to_i + quantidade
    salva_carrinho!
    sucesso("\"#{produto.nome}\" adicionado ao carrinho.")
    redirect '/carrinho'
  end

  get '/carrinho' do
    @itens = itens_do_carrinho
    @total = @itens.sum { |item| item[:subtotal] }
    erb :'carrinho/show'
  end

  post '/carrinho/itens/:produto_id/remover' do
    carrinho.delete(params[:produto_id].to_s)
    salva_carrinho!
    sucesso('Item removido do carrinho.')
    redirect '/carrinho'
  end

  post '/carrinho/finalizar' do
    requer_login!
    begin
      vendas = Venda.registrar_compra!(comprador: usuario_atual, carrinho: carrinho)
      session[:carrinho] = {}
      sucesso("Compra finalizada: #{vendas.size} venda(s) registrada(s).")
      redirect '/minhas-compras'
    rescue Venda::ErroDeCompra, ActiveRecord::RecordInvalid => e
      erro("Não foi possível finalizar: #{e.message}")
      redirect '/carrinho'
    end
  end

  get '/minhas-compras' do
    requer_login!
    @compras = usuario_atual.compras
                            .includes(:vendedor, item_vendas: :produto)
                            .order(data: :desc, id: :desc)
    erb :'compras/index'
  end

  post '/compras/:id/cancelar' do
    requer_login!
    venda = usuario_atual.compras.find_by(id: params[:id])
    if venda.nil?
      erro('Compra não encontrada ou não pertence a você.')
      redirect '/minhas-compras'
    end

    begin
      venda.cancelar!
      sucesso("Compra ##{venda.id} cancelada e estoque estornado.")
    rescue Venda::ErroDeCompra, ActiveRecord::RecordInvalid => e
      erro("Não foi possível cancelar: #{e.message}")
    end
    redirect '/minhas-compras'
  end

  get '/vendas-recebidas' do
    requer_login!
    @vendas = usuario_atual.vendas_como_vendedor
                           .includes(:comprador, item_vendas: :produto)
                           .order(data: :desc, id: :desc)
    erb :'vendas/index'
  end

  post '/vendas/:id/avancar' do
    requer_login!
    venda = usuario_atual.vendas_como_vendedor.find_by(id: params[:id])
    if venda.nil?
      erro('Venda não encontrada ou não pertence a você.')
      redirect '/vendas-recebidas'
    end

    begin
      venda.avancar_status!
      sucesso("Venda ##{venda.id}: situação agora é \"#{venda.status}\".")
    rescue Venda::ErroDeCompra, ActiveRecord::RecordInvalid => e
      erro("Não foi possível avançar: #{e.message}")
    end
    redirect '/vendas-recebidas'
  end
end

require_relative 'models/usuario'
require_relative 'models/produto'
require_relative 'models/venda'
require_relative 'models/item_venda'