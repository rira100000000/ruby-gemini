# frozen_string_literal: true

require_relative "lib/gemini/version"

Gem::Specification.new do |spec|
  spec.name = "ruby-gemini-api"
  spec.version = Gemini::VERSION
  spec.authors = ["rira100000000"]
  spec.email = ["101010hayakawa@gmail.com"]

  spec.summary = "Ruby client for Google's Gemini API"
  spec.description = "A simple Ruby wrapper for interacting with Google Gemini API"
  spec.homepage = "https://github.com/rira100000000/ruby-gemini-api"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # 実行時の依存関係
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-multipart", "~> 1.0"
  spec.add_dependency "json", "~> 2.0"

  # 開発時の依存関係
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
  spec.add_development_dependency "webmock", "~> 3.0"
  spec.add_development_dependency "dotenv", "~> 2.0"
  spec.add_development_dependency "vcr", "~> 6.3.1"

  # ファイル指定
  spec.files = Dir.glob("{lib,sig}/**/*") + ["README.md", "LICENSE.txt", "CHANGELOG.md"]
  spec.require_paths = ["lib"]
end