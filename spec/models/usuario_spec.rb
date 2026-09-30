require 'spec_helper'

RSpec.describe Usuario do
  describe 'atributos' do
    it 'persiste nome, email, cpf e telefone' do
      usuario = cria_usuario(nome: 'Ana', email: 'ana@exemplo.com',
                             cpf: '11122233344', telefone: '62999990000')
      usuario.reload

      expect(usuario.nome).to eq('Ana')
      expect(usuario.email).to eq('ana@exemplo.com')
      expect(usuario.cpf).to eq('11122233344')
      expect(usuario.telefone).to eq('62999990000')
    end

    it 'guarda o hash da senha, nunca o texto puro' do
      usuario = cria_usuario(senha: 'segredo123')

      expect(usuario.senha_hash).not_to eq('segredo123')
      expect(usuario.autentica('segredo123')).to be(true)
      expect(usuario.autentica('errado')).to be(false)
    end
  end

  describe 'associações' do
    it 'tem muitos produtos como vendedor' do
      vendedor = cria_usuario
      cria_produto(vendedor: vendedor)
      cria_produto(vendedor: vendedor)

      expect(vendedor.produtos.count).to eq(2)
    end

    it 'separa vendas_como_vendedor de compras no mesmo usuario' do
      vendedor  = cria_usuario
      comprador = cria_usuario
      venda = cria_venda(comprador: comprador, vendedor: vendedor)

      expect(vendedor.vendas_como_vendedor).to include(venda)
      expect(vendedor.compras).to be_empty
      expect(comprador.compras).to include(venda)
      expect(comprador.vendas_como_vendedor).to be_empty
    end

    it 'permite ao mesmo usuario ser vendedor e comprador' do
      pessoa = cria_usuario
      outro  = cria_usuario
      cria_produto(vendedor: pessoa)
      cria_venda(comprador: pessoa, vendedor: outro)
      cria_venda(comprador: outro,  vendedor: pessoa)

      expect(pessoa.produtos.count).to eq(1)
      expect(pessoa.compras.count).to eq(1)
      expect(pessoa.vendas_como_vendedor.count).to eq(1)
    end
  end

  describe 'validações' do
    it 'exige nome, cpf e senha' do
      usuario = Usuario.new(email: 'x@exemplo.com')

      expect(usuario).not_to be_valid
      expect(usuario.errors[:nome]).not_to be_empty
      expect(usuario.errors[:cpf]).not_to be_empty
      expect(usuario.errors[:senha_hash]).not_to be_empty
    end

    it 'exige email' do
      usuario = Usuario.new(nome: 'X', cpf: '1', senha: 'a')

      expect(usuario).not_to be_valid
      expect(usuario.errors[:email]).not_to be_empty
    end

    it 'rejeita email com formato invalido' do
      usuario = Usuario.new(nome: 'X', cpf: '1', senha: 'a', email: 'nao-e-email')

      expect(usuario).not_to be_valid
      expect(usuario.errors[:email]).not_to be_empty
    end

    it 'rejeita email repetido, ignorando maiusculas' do
      cria_usuario(email: 'ana@exemplo.com')
      usuario = Usuario.new(nome: 'Outra', cpf: '2', senha: 'b', email: 'ANA@EXEMPLO.COM')

      expect(usuario).not_to be_valid
      expect(usuario.errors[:email]).not_to be_empty
    end

    it 'aceita um usuario completo' do
      expect(Usuario.new(nome: 'X', cpf: '1', senha: 'a', email: 'x@exemplo.com')).to be_valid
    end
  end
end