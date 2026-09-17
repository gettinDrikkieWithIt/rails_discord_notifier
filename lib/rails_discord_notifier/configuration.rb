# frozen_string_literal: true

require "logger"
require "uri"

module RailsDiscordNotifier
  # Holds every tunable setting. Defaults are chosen so that installing the gem
  # and doing nothing else is safe: silent in development and test, and inert
  # until a plausible Discord webhook URL is supplied.
  class Configuration
    # Discord only accepts webhooks on these hosts. Anything else is either a
    # misconfiguration or an attempt to point the notifier at a third party.
    WEBHOOK_HOSTS = %w[discord.com discordapp.com].freeze

    # Noisy, client-caused exceptions that almost always mean "bad request",
    # not "bug worth waking someone for".
    DEFAULT_IGNORED_EXCEPTIONS = %w[
      AbstractController::ActionNotFound
      ActionController::BadRequest
      ActionController::InvalidAuthenticityToken
      ActionController::InvalidCrossOriginRequest
      ActionController::MethodNotAllowed
      ActionController::NotImplemented
      ActionController::RoutingError
      ActionController::UnknownAction
      ActionController::UnknownFormat
      ActionController::UnknownHttpMethod
      ActionDispatch::Http::MimeNegotiation::InvalidType
      ActionDispatch::Http::Parameters::ParseError
      ActionDispatch::RemoteIp::IpSpoofAttackError
      ActiveRecord::RecordNotFound
      Rack::QueryParser::InvalidParameterError
      Rack::QueryParser::ParameterTypeError
    ].freeze

    NON_REPORTING_ENVIRONMENTS = %w[development test].freeze

    # Substring matchers handed to ActiveSupport::ParameterFilter. Unioned with
    # the host application's own config.filter_parameters, never replacing it.
    DEFAULT_FILTER_PARAMETERS = %w[
      passw secret token _key crypt salt certificate otp ssn
      signature authorization cookie session credential
    ].freeze

    attr_accessor :webhook_url, :username, :avatar_url, :async,
                  :open_timeout, :read_timeout, :write_timeout, :throttle_period,
                  :include_params, :ignored_exceptions, :release, :context,
                  :backtrace_lines, :install_middleware, :install_error_subscriber
    attr_writer :logger, :environment, :filter_parameters, :enabled

    def initialize
      @webhook_url        = nil
      @username           = "Error Bot"
      @avatar_url         = nil
      @enabled            = nil
      @async              = true
      @open_timeout       = 2
      @read_timeout       = 5
      @write_timeout      = 5
      @throttle_period    = 60
      @include_params     = true
      @ignored_exceptions = DEFAULT_IGNORED_EXCEPTIONS.dup
      @backtrace_lines    = 10
      @install_middleware = true
      @install_error_subscriber = true
      @filter_parameters  = nil
      @release            = nil
      @context            = nil
    end

    # Tracks the environment until something sets it explicitly, so correcting
    # `environment` after construction still does the right thing.
    def enabled
      @enabled.nil? ? default_enabled? : @enabled
    end

    # True only when the notifier should actually talk to Discord.
    def enabled?
      !!enabled && valid_webhook_url?
    end

    def valid_webhook_url?
      uri = parsed_webhook_url
      return false if uri.nil?

      uri.scheme == "https" && discord_host?(uri.host)
    end

    def ignore?(exception)
      ancestry = exception.class.ancestors.map(&:to_s)
      ignored_exceptions.any? { |name| ancestry.include?(name.to_s) }
    end

    def logger
      @logger ||= rails_logger || Logger.new($stderr)
    end

    # Always a superset of the host application's filters, so opting into this
    # gem can never redact less than the app already does.
    def filter_parameters
      (Array(@filter_parameters) + rails_filter_parameters + DEFAULT_FILTER_PARAMETERS).uniq
    end

    def environment
      @environment ||= rails_env || ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
    end

    private

    def parsed_webhook_url
      return nil if webhook_url.nil? || webhook_url.to_s.strip.empty?

      URI.parse(webhook_url.to_s.strip)
    rescue URI::InvalidURIError
      nil
    end

    # Matches the host exactly or as a subdomain, so "notdiscord.com" is rejected.
    def discord_host?(host)
      return false if host.nil?

      host = host.downcase
      WEBHOOK_HOSTS.any? { |allowed| host == allowed || host.end_with?(".#{allowed}") }
    end

    def default_enabled?
      !NON_REPORTING_ENVIRONMENTS.include?(environment.to_s)
    end

    def rails_logger
      Rails.logger if defined?(Rails) && Rails.respond_to?(:logger)
    end

    def rails_env
      Rails.env.to_s if defined?(Rails) && Rails.respond_to?(:env) && Rails.env
    end

    def rails_filter_parameters
      return [] unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application

      Array(Rails.application.config.filter_parameters)
    rescue StandardError
      []
    end
  end
end
