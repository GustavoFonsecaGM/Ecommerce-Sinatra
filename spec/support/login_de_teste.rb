
module LoginDeTeste
  def loga(usuario, senha: 'segredo123')
    post '/login', email: usuario.email, senha: senha
  end
end