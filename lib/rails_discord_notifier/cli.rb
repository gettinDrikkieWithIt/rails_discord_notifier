# frozen_string_literal: true

module RailsDiscordNotifier
  # `rails_discord_notifier test` posts a real message to your webhook and prints
  # what Discord said. It answers the first question every user of this gem has:
  # "is my webhook actually wired up?"
  class CLI
    USAGE = <<~TEXT
      Usage: rails_discord_notifier <command> [options]

      Commands:
        test       Send a sample exception report to your Discord webhook
        version    Print the gem version
        help       Show this message

      Options:
        --webhook URL   Webhook to use (defaults to $DISCORD_WEBHOOK_URL)
    TEXT

    def initialize(argv, out: $stdout, env: ENV)
      @argv = Array(argv)
      @out  = out
      @env  = env
    end

    # Returns a process exit status.
    def run
      case @argv.first
      when "test"    then run_test
      when "version" then print_version
      when "help", nil then usage(0)
      else usage(1)
      end
    end

    private

    def run_test
      config = test_config
      unless config.valid_webhook_url?
        @out.puts(webhook_help)
        return 1
      end

      @out.puts("Posting a sample exception report to Discord…")
      deliver(config)
    end

    def deliver(config)
      if Client.new(config).post(sample_payload(config))
        @out.puts("Sent. Check your Discord channel.")
        0
      else
        @out.puts("Discord did not accept the message. See the logged response above.")
        1
      end
    end

    def sample_payload(config)
      exception = begin
        raise "RailsDiscordNotifier test message - everything is wired up correctly"
      rescue StandardError => e
        e
      end
      Payload.new(exception, config: config).to_h
    end

    def test_config
      Configuration.new.tap do |config|
        config.webhook_url = webhook_url
        config.enabled     = true
        config.async       = false
        config.logger      = Logger.new(@out)
      end
    end

    def webhook_url
      index = @argv.index("--webhook")
      return @argv[index + 1] if index && @argv[index + 1]

      @env["DISCORD_WEBHOOK_URL"]
    end

    def webhook_help
      if webhook_url.to_s.strip.empty?
        "No webhook configured. Set DISCORD_WEBHOOK_URL or pass --webhook URL."
      else
        "Invalid webhook: expected an https://discord.com/api/webhooks/... URL, got #{webhook_url}"
      end
    end

    def print_version
      @out.puts(VERSION)
      0
    end

    def usage(status)
      @out.puts(USAGE)
      status
    end
  end
end
