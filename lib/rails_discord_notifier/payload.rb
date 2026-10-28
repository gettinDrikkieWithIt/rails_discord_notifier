# frozen_string_literal: true

require "digest"
require "json"
require "rack"
require "socket"
require "time"
require "active_support/parameter_filter"

module RailsDiscordNotifier
  # Turns an exception (plus optional Rack env) into a Discord webhook body.
  #
  # Parameters and query strings are filtered structurally; exception messages
  # get a best-effort scrub of "secret=value" style fragments, since a message is
  # free text and cannot be filtered with certainty.
  #
  # Everything is truncated to Discord's documented limits. Exceeding a limit
  # makes Discord reject the whole message with HTTP 400, which would silently
  # lose the very error being reported.
  class Payload
    TITLE_LIMIT       = 256
    DESCRIPTION_LIMIT = 4096
    FIELD_NAME_LIMIT  = 256
    FIELD_VALUE_LIMIT = 1024
    FIELD_COUNT_LIMIT = 25
    EMBED_TOTAL_LIMIT = 6000

    RED       = 16_711_680
    ELLIPSIS  = "…"
    JSON_FENCE_OVERHEAD = "```json\n\n```".length

    # Fields sacrificed, in order, when an embed would breach the 6000 character
    # total. Backtrace is never dropped: it is the reason the message exists.
    DROP_ORDER = ["Params", "User Agent", "Host", "Request ID", "Release",
                  "Environment", "Action", "Controller", "URL"].freeze

    # The payload for whichever service the configured webhook belongs to.
    def self.build(exception, config:, **options)
      (config.google_chat? ? GoogleChatPayload : Payload).new(exception, config: config, **options)
    end

    def initialize(exception, config:, env: nil, context: {})
      @exception = exception
      @config    = config
      @env       = env
      @context   = context || {}
    end

    def to_h
      @to_h ||= { username: config.username, avatar_url: config.avatar_url, embeds: [embed] }.compact
    end

    def size
      embed_size(embed)
    end

    # Stable identity for an error occurrence, used to throttle repeats. Keyed on
    # the route, not the path, so /users/1, /users/2 and /users/1.json are one
    # error rather than a way around the throttle.
    def fingerprint
      @fingerprint ||= Digest::SHA256.hexdigest(
        [exception.class.name, Array(exception.backtrace).first, *rails_params.values_at("controller", "action")].join("|")
      )
    end

    private

    attr_reader :exception, :config, :env, :context

    def embed
      @embed ||= enforce_total_budget(
        {
          title: truncate(title, TITLE_LIMIT),
          description: truncate(description, DESCRIPTION_LIMIT),
          color: RED,
          timestamp: Time.now.utc.iso8601,
          fields: fields
        }
      )
    end

    def title
      request ? "Exception in #{env["REQUEST_METHOD"]} #{request.path}" : exception.class.name
    end

    def description
      [exception, exception.cause].compact
                                  .map { |error| "#{bold(error.class)}: #{scrubber.scrub(error.message)}" }
                                  .join("\nCaused by ")
    end

    def bold(text)
      "**#{text}**"
    end

    def scrubber
      @scrubber ||= SecretScrubber.new(config.filter_parameters)
    end

    def fields
      droppable = (request_fields + context_fields + [params_field])
                  .compact.reject { |f| blank?(f[:value]) }
                  .first(FIELD_COUNT_LIMIT - 1)
      (droppable + [backtrace_field]).map { |field| normalize_field(field) }
    end

    def normalize_field(field)
      { name: truncate(field[:name].to_s, FIELD_NAME_LIMIT),
        value: truncate(field[:value].to_s, FIELD_VALUE_LIMIT),
        inline: field.fetch(:inline, false) }
    end

    def request_fields
      [
        { name: "URL", value: request_url },
        { name: "Controller", value: rails_params["controller"], inline: true },
        { name: "Action", value: rails_params["action"], inline: true },
        { name: "Environment", value: config.environment, inline: true },
        { name: "Release", value: config.release, inline: true },
        { name: "Request ID", value: env && env["action_dispatch.request_id"], inline: true },
        { name: "Host", value: hostname, inline: true },
        { name: "User Agent", value: request&.user_agent }
      ]
    end

    # ParameterFilter only walks into real Hashes, so ActionController::Parameters
    # is unwrapped first. Context the filter cannot process is left out: sending
    # it unfiltered could leak, and failing here would drop the whole report.
    def context_fields
      extra = context.merge(configured_context)
                     .transform_values { |value| value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value }
      parameter_filter.filter(extra).map { |name, value| { name: name.to_s, value: value.to_s, inline: true } }
    rescue StandardError => e
      config.logger.warn("[RailsDiscordNotifier] context left out, the filter raised #{e.class}: #{e.message}")
      []
    end

    def configured_context
      return {} unless config.context.respond_to?(:call)

      Hash(config.context.call(env))
    rescue StandardError => e
      config.logger.warn("[RailsDiscordNotifier] config.context raised #{e.class}: #{e.message}")
      {}
    end

    def params_field
      return nil unless config.include_params && request

      { name: "Params", value: formatted_params }
    end

    def formatted_params
      filtered = parameter_filter.filter(request_params.except("controller", "action", "format"))
      return nil if filtered.empty?

      fence(JSON.pretty_generate(filtered))
    rescue StandardError
      "Could not parse params"
    end

    # Truncates the JSON *inside* the fence so the closing ``` always survives.
    def fence(json)
      "```json\n#{truncate(json, FIELD_VALUE_LIMIT - JSON_FENCE_OVERHEAD)}\n```"
    end

    def backtrace_field
      { name: "Backtrace", value: formatted_backtrace }
    end

    def formatted_backtrace
      lines = clean_backtrace
      return "No backtrace available" if lines.empty?

      lines.each_with_object(+"") do |line, out|
        entry = "`#{line}`"
        break out if out.length + entry.length + 1 > FIELD_VALUE_LIMIT

        out << "\n" unless out.empty?
        out << entry
      end
    end

    # The app's own frames, as on Rails' error pages, so the lines that matter
    # fit the message. An error raised entirely inside library code keeps its
    # library frames, with gem paths shortened. Raw frames when the cleaner is
    # unavailable (no Rails) or raises, and without an app root: Rails 6.1 and
    # 7.0 would then strip the leading "/" from every path.
    def clean_backtrace
      lines = Array(exception.backtrace)
      return lines.first(config.backtrace_lines) unless Rails.root

      app_frames = Rails.backtrace_cleaner.clean(lines)
      (app_frames.empty? ? Rails.backtrace_cleaner.clean(lines, :all) : app_frames).first(config.backtrace_lines)
    rescue StandardError
      Array(exception.backtrace).first(config.backtrace_lines)
    end

    # Without the query string: its values reach the report only through the
    # filtered Params field, so include_params = false sends none of them.
    def request_url
      request && "#{request.base_url}#{request.path}"
    end

    def request_params
      request.params
    rescue StandardError
      {}
    end

    def rails_params
      return {} unless env

      env["action_dispatch.request.parameters"] || {}
    rescue StandardError
      {}
    end

    def request
      return @request if defined?(@request)

      @request = env.nil? ? nil : build_request
    end

    def build_request
      if defined?(ActionDispatch::Request)
        ActionDispatch::Request.new(env)
      else
        Rack::Request.new(env)
      end
    rescue StandardError
      nil
    end

    def parameter_filter
      @parameter_filter ||= ActiveSupport::ParameterFilter.new(config.filter_parameters)
    end

    # Heroku hostnames are random IDs; DYNO ("web.1", "worker.2") names the process.
    def hostname
      dyno = ENV.fetch("DYNO", "")
      @hostname ||= dyno.empty? ? Socket.gethostname : dyno
    rescue StandardError
      nil
    end

    def enforce_total_budget(embed)
      DROP_ORDER.each do |name|
        break if embed_size(embed) <= EMBED_TOTAL_LIMIT

        embed[:fields] = embed[:fields].reject { |f| f[:name] == name }
      end
      drop_remaining_fields(embed)
      shrink_description(embed) if embed_size(embed) > EMBED_TOTAL_LIMIT
      embed
    end

    # Whatever is still over budget can only be caller-supplied context, which
    # DROP_ORDER cannot name. Shed it from the end, never the backtrace.
    def drop_remaining_fields(embed)
      while embed_size(embed) > EMBED_TOTAL_LIMIT
        index = embed[:fields].rindex { |f| f[:name] != "Backtrace" }
        break if index.nil?

        embed[:fields].delete_at(index)
      end
    end

    def shrink_description(embed)
      allowance = EMBED_TOTAL_LIMIT - (embed_size(embed) - embed[:description].length)
      embed[:description] = truncate(embed[:description], [allowance, 0].max)
    end

    def embed_size(embed)
      embed[:title].to_s.length + embed[:description].to_s.length +
        embed[:fields].sum { |f| f[:name].to_s.length + f[:value].to_s.length }
    end

    def truncate(string, limit)
      string = SecretScrubber.utf8(string)
      return string if string.length <= limit
      return string[0, limit].to_s if limit < ELLIPSIS.length

      "#{string[0, limit - ELLIPSIS.length]}#{ELLIPSIS}"
    end

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end
  end
end
