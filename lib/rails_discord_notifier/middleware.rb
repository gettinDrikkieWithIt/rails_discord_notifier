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
    rescue Exception => e
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
    rescue => send_error
      Rails.logger.error "RailsDiscordNotifier failed: #{send_error.class}: #{send_error.message}"
    end

    def build_payload(exception, env)
      request = Rack::Request.new(env)
      {
        username:    RailsDiscordNotifier.username,
        avatar_url:  RailsDiscordNotifier.avatar_url,
        embeds: [
                       {
                         title:       "Exception in #{env['REQUEST_METHOD']} #{env['PATH_INFO']}",
                         description: "**#{exception.class}**: #{exception.message}",
                         color:       16711680, # red
                         fields: [
                                   { name: "URL",          value: request.url, inline: false },
                                   { name: "Controller",   value: env['action_dispatch.request.parameters']['controller'], inline: true },
                                   { name: "Action",       value: env['action_dispatch.request.parameters']['action'],     inline: true },
                                   { name: "Params",       value: format_params(request.params),                              inline: false },
                                   { name: "Backtrace",    value: format_backtrace(exception.backtrace),                   inline: false },
                                   { name: "User Agent",   value: request.user_agent.to_s,                                 inline: false },
                                   { name: "Timestamp",    value: Time.now.utc.iso8601,                                   inline: false }
                                 ]
                       }
                     ]
      }
    end

    def format_backtrace(bt)
      bt.first(5).map { |line| "`#{line}`" }.join("\n")
    end

    def format_params(params)
      filtered = params.reject { |k, _| %w(controller action format).include?(k) }
      return "None" if filtered.empty?
      "```json\n#{JSON.pretty_generate(filtered)}\n```"
    rescue
      "Could not parse params"
    end
  end
end
