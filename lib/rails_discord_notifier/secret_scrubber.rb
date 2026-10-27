# frozen_string_literal: true

module RailsDiscordNotifier
  # Removes credential-looking fragments from free text.
  #
  # Exception messages cannot be filtered the way structured parameters can, so
  # this is deliberately a best effort: it catches the shapes credentials
  # actually take when they end up in a message - `token=abc`, `password="x"`,
  # `Api_Key: abc`, `"password":"x"`, `Authorization: Bearer abc`,
  # `redis://:pw@host` - and leaves ordinary prose ("password reset email") alone.
  class SecretScrubber
    KEY_CHAR = '[\w.\[\]-]'
    # An optional closing quote on the key, then `=`, `:` or `=>`.
    SEPARATOR = %q{(["']?\s*(?:=>|[=:])\s*)}
    # A quoted string, an HTTP auth scheme with its credential, or one word.
    VALUE = %q{(?:"[^"]*"|'[^']*'|(?:bearer|basic)\s+\S+|\S+)}
    URL_PASSWORD = %r{(://[^:/@\s]*:)[^@/\s]+(@)}

    def initialize(matchers)
      @matchers = matchers
    end

    # Key patterns run first: URL_PASSWORD would otherwise read "host:8443?token=s3cr@"
    # as a username and password, and swallow the key that marks the real secret.
    def scrub(text)
      scrubbed = patterns.reduce(text.to_s.dup.force_encoding(Encoding::UTF_8).scrub) do |result, pattern|
        result.gsub(pattern) { "#{Regexp.last_match(1)}#{Regexp.last_match(2)}[FILTERED]" }
      end
      scrubbed.gsub(URL_PASSWORD) { "#{Regexp.last_match(1)}[FILTERED]#{Regexp.last_match(2)}" }
    end

    private

    # Regexp and Proc filters are skipped: they are written to match parameter
    # keys, not the inside of a sentence.
    #
    # A key may only start where a run of key characters starts, and is matched
    # atomically. That keeps matching linear: before Ruby 3.2 the unanchored form
    # took cubic time on input like "tokentoken…", stalling the whole process.
    def patterns
      @patterns ||= @matchers.filter_map do |matcher|
        next unless matcher.is_a?(String) || matcher.is_a?(Symbol)

        key = "(?<!#{KEY_CHAR})((?>#{KEY_CHAR}*?#{Regexp.escape(matcher.to_s)}#{KEY_CHAR}*+))"
        /#{key}#{SEPARATOR}#{VALUE}/i
      end
    end
  end
end
