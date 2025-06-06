# frozen_string_literal: true

require "paychangu"
require 'webmock/rspec'

RSpec.configure do |config|
  WebMock.disable_net_connect!(allow_localhost: true)
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
