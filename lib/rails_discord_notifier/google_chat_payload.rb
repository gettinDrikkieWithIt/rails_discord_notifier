# frozen_string_literal: true

module RailsDiscordNotifier
  # Turns an exception (plus optional Rack env) into a Google Chat webhook body.
  #
  # Gathers, redacts and budgets exactly what the Discord payload does, then
  # renders it as one plain-text message. Discord's 6000 character embed budget
  # keeps the result far below Google Chat's 32,000 byte message limit.
  class GoogleChatPayload < Payload
    CODE_FENCE = "```"
    CODE_BLOCK_OVERHEAD = "#{CODE_FENCE}\n\n#{CODE_FENCE}".length

    # Chat renders "<users/all>" as an @all mention and "<url|text>" as a masked
    # link. A zero-width space after every "<" defuses both without changing
    # what the message looks like. The message itself never needs a "<".
    MARKUP_OPENER = "<"
    DEFUSED_OPENER = "<\u200B"

    def to_h
      @to_h ||= { text: render(embed).gsub(MARKUP_OPENER, DEFUSED_OPENER) }
    end

    private

    def render(embed)
      heading = [bold(embed[:title]), embed[:description], ""]
      (heading + embed[:fields].map { |field| render_field(field) }).join("\n")
    end

    def render_field(field)
      separator = field[:value].include?("\n") ? "\n" : " "
      "#{bold("#{field[:name]}:")}#{separator}#{field[:value]}"
    end

    def bold(text)
      "*#{text}*"
    end

    # Chat code blocks take no language tag; a "json" one would be shown as text.
    def fence(text)
      "#{CODE_FENCE}\n#{truncate(text, FIELD_VALUE_LIMIT - CODE_BLOCK_OVERHEAD)}\n#{CODE_FENCE}"
    end

    def formatted_backtrace
      lines = Array(exception.backtrace).first(config.backtrace_lines)
      return "No backtrace available" if lines.empty?

      fence(lines.join("\n"))
    end
  end
end
