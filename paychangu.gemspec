# frozen_string_literal: true

require_relative "lib/paychangu/version"

Gem::Specification.new do |spec|
  spec.name = "Paychangu"
  spec.version = Paychangu::VERSION
  spec.authors = ["Danny Simfukwe"]
  spec.email = ["dannysimfukwe@gmail.com"]

  spec.summary = "Paychangu is a Ruby gem that allows you to interact with Paychangu.com's API."
  spec.description = "Paychangu is a Ruby gem that allows you to interact with Paychangu.com's API and perform several operations like: creating payment links, creating virtual cards etc"
  spec.homepage = "https://github.com/dannysimfukwe/paychangugem"
  spec.license = "MIT"
  spec.required_ruby_version = "~> 3.3.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/dannysimfukwe/paychangugem"
  spec.metadata["changelog_uri"] = "https://github.com/dannysimfukwe/paychangugem"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "httparty", "~> 0.20"
  spec.add_development_dependency "webmock", "~> 3.18"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata["rubygems_mfa_required"] = "false"
end
