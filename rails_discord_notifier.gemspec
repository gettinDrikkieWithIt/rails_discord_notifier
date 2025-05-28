# frozen_string_literal: true

require_relative "lib/rails_discord_notifier/version"

Gem::Specification.new do |spec|
  spec.name    = "rails_discord_notifier"
  spec.version = RailsDiscordNotifier::VERSION
  spec.authors = ["GettinDrikkieWithIt"]
  spec.email   = ["33983365+gettinDrikkieWithIt@users.noreply.github.com"]

  spec.summary     = "Send Rails exceptions to Discord via configurable webhook"
  spec.description = <<~DESC
    RailsDiscordNotifier captures unhandled exceptions in your Rails application
    and sends detailed error reports to a Discord channel using an incoming webhook.
    Customize the bot username, avatar, and message format via initializer.
  DESC

  spec.homepage              = "https://github.com/gettinDrikkieWithIt/rails_discord_notifier"
  spec.license               = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.1.0")

  # Only gems fetched from RubyGems.org will be pushed by default
  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  # Links for users and contributors
  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Files to include in the gem
  gemspec_file = File.basename(__FILE__)
  spec.files   = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.read.split("\x0").reject do |f|
      f == gemspec_file ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "rails", ">= 5.2"

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
end
