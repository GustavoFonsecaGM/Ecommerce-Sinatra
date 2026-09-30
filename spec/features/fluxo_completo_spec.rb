require 'spec_helper'

RSpec.feature 'Fluxo completo de compra e venda' do
  def cadastra(nome:, email:)
    visit '/cadastro'
    fill_in 'Nome',   with: nome
    fill_in 'E-mail', with: email
    fill_in 'CPF',    with: '11122233344'
    fill_in 'Senha',  with: 'segredo123'
    click_button 'Cadastrar'
  end

  def entra(email:)
    visit '/login'
    fill_in 'E-mail', with: email
    fill_in 'Senha',  with: 'segredo123'
    click_button 'Entrar'
  end

  scenario 'vendedor publica, comprador compra e vendedor entrega' do
    # ---------- vendedor se cadastra e publica um produto ----------
    cadastra(nome: 'Vera Vendedora', email: 'vera@exemplo.com')
    expect(page).to have_content('Cadastro realizado')

    click_link 'Meus produtos'
    click_link 'Cadastrar produto'
    fill_in 'Nome',    with: 'Caneca de porcelana'
    fill_in 'Preço',   with: '19.90'
    fill_in 'Estoque', with: '5'
    click_button 'Cadastrar'
    expect(page).to have_content('cadastrado')

    click_button 'Sair'

    # ---------- comprador se cadastra, busca e compra ----------
    cadastra(nome: 'Caio Comprador', email: 'caio@exemplo.com')

    click_link 'Produtos'
    fill_in 'Buscar', with: 'Caneca'
    click_button 'Buscar'
    expect(page).to have_content('Caneca de porcelana')

    click_link 'Ver detalhes'
    fill_in 'Quantidade', with: '2'
    click_button 'Adicionar ao carrinho'
    expect(page).to have_content('adicionado ao carrinho')
    expect(page).to have_content('R$ 39,80')

    click_button 'Finalizar compra'
    expect(page).to have_content('Compra finalizada')

    # ---------- minhas compras mostra a venda pendente ----------
    expect(page).to have_content('pendente')
    expect(page).to have_content('Vera Vendedora')
    expect(page).to have_content('R$ 39,80')

    click_button 'Sair'

    # ---------- vendedor acompanha e avanca ate a entrega ----------
    entra(email: 'vera@exemplo.com')
    click_link 'Vendas recebidas'
    expect(page).to have_content('Caio Comprador')
    expect(page).to have_content('pendente')

    click_button 'Avançar'
    expect(page).to have_content('paga')

    click_button 'Avançar'
    expect(page).to have_content('enviada')

    click_button 'Avançar'
    expect(page).to have_content('entregue')
    expect(page).to have_content('Sem próxima situação')
    expect(page).not_to have_button('Avançar')

    # ---------- e o estoque foi debitado ----------
    expect(Produto.find_by(nome: 'Caneca de porcelana').estoque).to eq(3)
  end

  scenario 'comprador cancela uma compra pendente e o estoque volta' do
    vendedor = cria_usuario(email: 'vera@exemplo.com', nome: 'Vera Vendedora')
    produto  = cria_produto(vendedor: vendedor, nome: 'Caneca', preco: '19.90', estoque: 5)

    cadastra(nome: 'Caio Comprador', email: 'caio@exemplo.com')

    visit "/produtos/#{produto.id}"
    fill_in 'Quantidade', with: '2'
    click_button 'Adicionar ao carrinho'
    click_button 'Finalizar compra'

    expect(page).to have_content('pendente')
    expect(produto.reload.estoque).to eq(3)

    click_button 'Cancelar compra'

    expect(page).to have_content('cancelada')
    expect(page).not_to have_button('Cancelar compra')
    expect(produto.reload.estoque).to eq(5)
  end
end