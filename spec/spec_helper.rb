require 'factory_girl'
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  begin
    config.filter_run :focus
    config.run_all_when_everything_filtered = true
    config.disable_monkey_patching!

    if config.files_to_run.one?
      config.default_formatter = 'doc'
    end

    config.order = :random

    config.include FactoryGirl::Syntax::Methods

    Kernel.srand config.seed
  end

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

end

# TY: https://gist.github.com/lehresman/794f261708c82962763f
module AuthRequestHelper
  def http_auth_as(username, password, &block)
    @env = {} unless @env
    old_auth = @env['HTTP_AUTHORIZATION']
    @env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
    yield block
    @env['HTTP_AUTHORIZATION'] = old_auth
  end

  def custom_http_auth_as(username, password, &block)
    @env = {} unless @env
    old_auth = @env['HTTP_CONDUCTOR_AUTHORIZATION']
    @env['HTTP_CONDUCTOR_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
    yield block
    @env['HTTP_CONDUCTOR_AUTHORIZATION'] = old_auth
  end

  def auth_get(url, params={}, env={})
    get url, params, @env.merge(env)
  end

  def auth_post(url, params={}, env={})
    post url, params, @env.merge(env)
  end

  def auth_put(url, params={}, env={})
    put url, params, @env.merge(env)
  end

  def auth_patch(url, params={}, env={})
    patch url, params, @env.merge(env)
  end

  def auth_delete(url, params={}, env={})
    delete url, params, @env.merge(env)
  end
end
