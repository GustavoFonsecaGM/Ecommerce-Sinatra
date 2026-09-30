ENV['RACK_ENV'] = 'test'


Dir[File.expand_path('../db/test.sqlite3*', __dir__)].each { |arquivo| File.delete(arquivo) }

require_relative '../app'
require 'rspec'
require 'rack/test'
require 'capybara/rspec'

BCrypt::Engine.cost = BCrypt::Engine::MIN_COST

ActiveRecord::Schema.verbose = false
load File.expand_path('../db/schema.rb', __dir__)   

Dir[File.expand_path('support/**/*.rb', __dir__)].sort.each { |arquivo| require arquivo }

Capybara.app = App
Capybara.default_driver = :rack_test
Capybara.save_path = 'spec/tmp'


TABELAS_PARA_LIMPAR = %w[item_vendas vendas produtos usuarios].freeze

module AppHelper
  def app
    App
  end
end

RSpec.configure do |config|
  config.include Rack::Test::Methods, type: :request
  config.include AppHelper, type: :request
  config.include LoginDeTeste, type: :request
  config.include Fabricas

  config.before(:each) do
    ActiveRecord::Base.connection_pool.with_connection do |conexao|
      TABELAS_PARA_LIMPAR.each { |tabela| conexao.execute("DELETE FROM #{tabela}") }
    end
  end

  config.expect_with(:rspec) { |c| c.syntax = :expect }
end