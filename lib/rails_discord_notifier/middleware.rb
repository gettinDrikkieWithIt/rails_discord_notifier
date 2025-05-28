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
      payload = {
        username: RailsDiscordNotifier.username,
        avatar_url: RailsDiscordNotifier.avatar_url,
        embeds: [
                    {
                      title: "#{exception.class} in #{env["REQUEST_METHOD"]} #{env["PATH_INFO"]}",
                      description: "```#{exception.message}```",
                      fields: [
                               { name: "URL", value: env["REQUEST_URI"] },
                               { name: "Backtrace", value: "```#{exception.backtrace.first(5).join("\n")}```" }
                             ],
                      timestamp: Time.now.utc.iso8601
                    }
                  ]
      }
      uri = URI(RailsDiscordNotifier.webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      req = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")
      req.body = JSON.generate(payload)
      http.request(req)
    rescue => send_error
      Rails.logger.error "RailsDiscordNotifier failed: #{send_error.class}: #{send_error.message}"
    end
  end
end
