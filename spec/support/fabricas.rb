module Fabricas
  def cria_usuario(email: nil, nome: 'Usuario Teste', cpf: '12345678901',
                   senha: 'segredo123', telefone: nil)
    Usuario.create!(
      nome: nome,
      email: email || "usuario-#{SecureRandom.hex(4)}@exemplo.com",
      cpf: cpf,
      senha: senha,
      telefone: telefone
    )
  end

  def cria_produto(vendedor:, nome: 'Produto Teste', descricao: nil,
                   preco: '19.90', estoque: 10)
    Produto.create!(
      nome: nome,
      descricao: descricao,
      preco: preco,
      estoque: estoque,
      vendedor: vendedor
    )
  end

  def cria_venda(comprador:, vendedor:, status: 'pendente',
                 data: Date.today, valor_total: 0)
    Venda.create!(
      comprador: comprador,
      vendedor: vendedor,
      data: data,
      status: status,
      valor_total: valor_total
    )
  end

  def cria_item(venda:, produto:, quantidade: 1, preco_unitario: nil)
    ItemVenda.create!(
      venda: venda,
      produto: produto,
      quantidade: quantidade,
      preco_unitario: preco_unitario || produto.preco
    )
  end
end