require "bundler/setup"
require "gemini"
require "webmock/rspec"
require "dotenv/load"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# テスト実行中は実際のAPIコールを防止
WebMock.disable_net_connect!(allow_localhost: true)