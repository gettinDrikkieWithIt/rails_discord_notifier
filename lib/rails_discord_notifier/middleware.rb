# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module RailsDiscordNotifier
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue StandardError => e
      notify_discord(e, env)
      raise
    end

    private

    def notify_discord(exception, env)
      payload = build_payload(exception, env)
      uri     = URI(RailsDiscordNotifier.webhook_url)
      http    = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"

      req = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")
      req.body = JSON.generate(payload)
      http.request(req)
    rescue StandardError => e
      Rails.logger.error "RailsDiscordNotifier failed: #{e.class}: #{e.message}"
    end

    def build_payload(exception, env)
      request = Rack::Request.new(env)
      params = env["action_dispatch.request.parameters"] || {}
      {
        username: RailsDiscordNotifier.username,
        avatar_url: RailsDiscordNotifier.avatar_url,
        embeds: [
          {
            title: "Exception in #{env["REQUEST_METHOD"]} #{env["PATH_INFO"]}",
            description: "**#{exception.class}**: #{exception.message}",
            color: 16_711_680, # red
            fields: [
              { name: "URL", value: request.url, inline: false },
              { name: "Controller",   value: params["controller"] || "N/A", inline: true },
              { name: "Action",       value: params["action"] || "N/A",     inline: true },
              { name: "Params",
                value: format_params(request.params), inline: false },
              { name: "Backtrace",
                value: format_backtrace(exception.backtrace),                   inline: false },
              { name: "User Agent",
                value: request.user_agent.to_s,                                 inline: false },
              { name: "Timestamp",
                value: Time.now.utc.iso8601, inline: false }
            ]
          }
        ]
      }
    end

    def format_backtrace(bt)
      return "No backtrace available" if bt.nil? || bt.empty?

      bt.first(5).map { |line| "`#{line}`" }.join("\n")
    end

    def format_params(params)
      filtered = params.except("controller", "action", "format")
      filtered = filter_sensitive_params(filtered)
      return "None" if filtered.empty?

      "```json\n#{JSON.pretty_generate(filtered)}\n```"
    rescue StandardError
      "Could not parse params"
    end

    def filter_sensitive_params(params)
      sensitive_keys = %w[password password_confirmation token api_key secret access_token refresh_token]
      params.each_with_object({}) do |(k, v), hash|
        hash[k] = sensitive_keys.any? { |s| k.to_s.downcase.include?(s) } ? "[FILTERED]" : v
      end
    end
  end
end
