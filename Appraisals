# frozen_string_literal: true

%w[6.1 7.0 7.1 7.2 8.0].each do |version|
  appraise "rails-#{version}" do
    gem "actionpack", "~> #{version}.0"
    gem "activesupport", "~> #{version}.0"
    gem "railties", "~> #{version}.0"

    # concurrent-ruby 1.3.5 stopped requiring "logger", which breaks
    # ActiveSupport before 7.1.
    gem "concurrent-ruby", "< 1.3.5" if version < "7.1"
  end
end
