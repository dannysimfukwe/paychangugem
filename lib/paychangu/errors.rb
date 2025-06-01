# frozen_string_literal: true

module Paychangu
  class Error < StandardError; end # General base error
  class APIError < Error # Base for errors from API responses
    def initialize(message = nil, response_body: nil, status_code: nil)
      @response_body = response_body
      @status_code = status_code
      super(message)
    end

    def to_s
      base_message = super
      details = []
      details << "Status: #{@status_code}" if @status_code
      details << "Response: #{@response_body}" if @response_body && !@response_body.empty?
      "#{base_message}#{" (#{details.join(', ')})" unless details.empty?}"
    end
  end
  class AuthenticationError < APIError; end # Inherits APIError's initialize
  class InvalidInputError < APIError; end   # Inherits APIError's initialize
  class NotFoundError < APIError; end # For 404 errors
  class BadRequestError < APIError; end # For 400 errors
  class UnprocessableEntityError < APIError; end # For 422 errors
end
