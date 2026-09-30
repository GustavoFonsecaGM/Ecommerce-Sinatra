class Usuario < ActiveRecord::Base
  has_many :produtos, foreign_key: :vendedor_id
  has_many :vendas_como_vendedor, class_name: 'Venda', foreign_key: :vendedor_id
  has_many :compras,              class_name: 'Venda', foreign_key: :comprador_id

  attr_reader :senha

  before_validation :normaliza_email

  validates :nome, presence: true
  validates :cpf,  presence: true
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :senha_hash, presence: true

  def senha=(texto_puro)
    @senha = texto_puro
    self.senha_hash = BCrypt::Password.create(texto_puro) if texto_puro.present?
  end

  def autentica(tentativa)
    return false if senha_hash.blank?
    BCrypt::Password.new(senha_hash) == tentativa
  end

  private

  def normaliza_email
    self.email = email.to_s.downcase.strip if email.present?
  end
end