# frozen_string_literal: true

module ExceptionHelpers
  # Real raise/rescue so the exception carries a genuine backtrace.
  def captured_exception(klass = RuntimeError, message = "boom")
    raise klass, message
  rescue StandardError => e
    e
  end

  def exception_with_backtrace(lines)
    RuntimeError.new("boom").tap { |e| e.set_backtrace(lines) }
  end
end

RSpec.configure { |config| config.include ExceptionHelpers }
