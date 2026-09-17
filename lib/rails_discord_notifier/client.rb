# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module RailsDiscordNotifier
  # Posts a prepared payload to the Discord webhook.
  #
  # Never raises: a notifier that breaks the request it is reporting on is worse
  # than no notifier. Every failure is logged and swallowed.
  class Client
    SUCCESS = (200..299)

    def initialize(config)
      @config = config
    end

    # Returns true when Discord accepted the message.
    def post(payload)
      uri = target_uri
      return false if uri.nil?

      accepted?(http(uri).request(build_request(uri, payload)))
    rescue StandardError => e
      config.logger.error("[RailsDiscordNotifier] delivery failed: #{e.class}: #{e.message}")
      false
    end

    private

    attr_reader :config

    def target_uri
      return nil unless config.valid_webhook_url?

      URI.parse(config.webhook_url.to_s.strip)
    rescue URI::InvalidURIError
      nil
    end

    def http(uri)
      Net::HTTP.new(uri.host, uri.port).tap do |http|
        http.use_ssl       = uri.scheme == "https"
        http.open_timeout  = config.open_timeout
        http.read_timeout  = config.read_timeout
        http.write_timeout = config.write_timeout
      end
    end

    def build_request(uri, payload)
      Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json").tap do |request|
        request.body = JSON.generate(payload)
      end
    end

    # Logs whatever Discord said, and answers whether the message got through.
    def accepted?(response)
      return true if SUCCESS.cover?(response.code.to_i)

      if response.code.to_i == 429
        config.logger.warn(
          "[RailsDiscordNotifier] rate limited by Discord, retry after #{response["Retry-After"] || "unknown"}s"
        )
      else
        config.logger.error(
          "[RailsDiscordNotifier] Discord rejected the message: HTTP #{response.code} #{response.body}"
        )
      end
      false
    end
  end
end
