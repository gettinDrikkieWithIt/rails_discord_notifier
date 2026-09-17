# frozen_string_literal: true

module RailsDiscordNotifier
  # Removes credential-looking fragments from free text.
  #
  # Exception messages cannot be filtered the way structured parameters can, so
  # this is deliberately a best effort: it catches the shapes credentials
  # actually take when they end up in a message - `token=abc`, `password="x"`,
  # `Api_Key: abc` - and leaves ordinary prose ("password reset email") alone.
  class SecretScrubber
    def initialize(matchers)
      @matchers = matchers
    end

    def scrub(text)
      patterns.reduce(text.to_s) do |scrubbed, pattern|
        scrubbed.gsub(pattern) { "#{Regexp.last_match(1)}#{Regexp.last_match(2)}[FILTERED]" }
      end
    end

    private

    # Regexp and Proc filters are skipped: they are written to match parameter
    # keys, not the inside of a sentence.
    def patterns
      @patterns ||= @matchers.filter_map do |matcher|
        next unless matcher.is_a?(String) || matcher.is_a?(Symbol)

        /([\w.\[\]-]*#{Regexp.escape(matcher.to_s)}[\w.\[\]-]*)(\s*[=:]\s*)("[^"]*"|'[^']*'|\S+)/i
      end
    end
  end
end
