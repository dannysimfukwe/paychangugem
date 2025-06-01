# frozen_string_literal: true

require "securerandom"
require 'httparty'

require_relative "paychangu/version"
require_relative "paychangu/errors"

# Provides classes and methods for interacting with the PayChangu API.
module Paychangu
  # Main class for interacting with the PayChangu Payment API.
  # It handles creating payment links, managing virtual cards, airtime purchases, and verifying payments.
  class Payment
    include HTTParty # Include HTTParty module
    base_uri 'https://api.paychangu.com' # Set base URI for all requests
    format :json # Default format for requests and responses

    # Supported currencies for general payments.
    SUPPORTED_CURRENCIES = %w[MWK NGN ZAR GBP USD ZMW].freeze
    # Supported currencies for virtual card operations.
    SUPPORTED_CARD_CURRENCIES = %w[USD].freeze

    # API endpoint paths used by the client.
    API_ENDPOINTS = {
      payment: "payment",
      create_card: "virtual_card/create",
      fund_card: "virtual_card/fund",
      withdraw: "virtual_card/withdraw",
      get_operators: "bill_payment/get-operators",
      airtime_payment: "bill_payment/create",
      verify_payment: "verify-payment"
    }.freeze

    # HTTP request methods supported.
    REQUEST_METHODS = {
      post: "POST",
      get: "GET",
      put: "PUT",
      delete: "DELETE"
    }.freeze

    def initialize(secret_key)
      @secret = paychangu_secret(secret_key)
      self.class.headers "Authorization" => "Bearer #{@secret}"
      self.class.headers "Accept" => "application/json"
      # Content-Type will be set per request if there's a body
    end

    # Initializes a new Payment client.
    # @param secret_key [String] Your PayChangu API secret key.
    # @raise [Paychangu::InvalidInputError] if the secret_key is nil or empty.
    def initialize(secret_key)
      @secret = paychangu_secret(secret_key)
      self.class.headers "Authorization" => "Bearer #{@secret}"
      self.class.headers "Accept" => "application/json"
      # Content-Type will be set per request if there's a body
    end

    # Creates a payment link.
    #
    # @param data [Hash] The payment data.
    # @option data [Float, Integer] :amount The amount for the payment.
    # @option data [String] :currency The currency code (e.g., "MWK", "USD"). See {SUPPORTED_CURRENCIES}.
    # @option data [String] :email The customer's email address.
    # @option data [String] :first_name The customer's first name.
    # @option data [String] :last_name The customer's last name.
    # @option data [String] :callback_url The URL to send a POST request to upon payment completion.
    # @option data [String] :return_url The URL to redirect the user to after payment.
    # @option data [String] :tx_ref (optional) Unique transaction reference. Auto-generated if not provided.
    # @option data [String] :title (optional) The title for the payment page customization.
    # @option data [String] :description (optional) The description for the payment page customization.
    # @option data [String] :logo (optional) URL to a logo for payment page customization.
    # @return [Hash] The API response containing the payment link details.
    # @raise [Paychangu::InvalidInputError] if required parameters are missing or invalid (e.g., unsupported currency).
    # @raise [Paychangu::AuthenticationError] if authentication fails.
    # @raise [Paychangu::APIError] for other API-related errors.
    def create_payment_link(data = {})
      required_keys = %i[amount currency email first_name last_name callback_url return_url]
      validate_presence_of(data, required_keys)

      payload = create_link_payload(data)

      process_request(payload, API_ENDPOINTS[:payment], REQUEST_METHODS[:post])
    end

    # Creates a virtual card.
    #
    # @param data [Hash] The virtual card data.
    # @option data [Float, Integer] :amount The initial amount to fund the card.
    # @option data [String] :currency The currency code (e.g., "USD"). See {SUPPORTED_CARD_CURRENCIES}.
    # @option data [String] :first_name The cardholder's first name.
    # @option data [String] :last_name The cardholder's last name.
    # @option data [String] :callback_url The URL to send a POST request to upon card event.
    # @return [Hash] The API response containing the virtual card details.
    # @raise [Paychangu::InvalidInputError] if required parameters are missing or invalid.
    # @raise [Paychangu::AuthenticationError] if authentication fails.
    # @raise [Paychangu::APIError] for other API-related errors.
    def create_virtual_card(data = {})
      required_keys = %i[amount currency first_name last_name callback_url]
      validate_presence_of(data, required_keys)
      payload = create_card_payload(data)

      process_request(payload, API_ENDPOINTS[:create_card], REQUEST_METHODS[:post])
    end

    # Funds a virtual card.
    #
    # @param data [Hash] The funding data.
    # @option data [Float, Integer] :amount The amount to fund.
    # @option data [String] :card_hash The hash of the card to fund.
    # @return [Hash] The API response confirming the funding.
    # @raise [Paychangu::InvalidInputError] if required parameters are missing.
    # @raise [Paychangu::AuthenticationError] if authentication fails.
    # @raise [Paychangu::APIError] for other API-related errors.
    def fund_card(data = {})
      required_keys = %i[amount card_hash]
      validate_presence_of(data, required_keys)
      payload = fund_card_payload(data)

      process_request(payload, API_ENDPOINTS[:fund_card], REQUEST_METHODS[:post])
    end

    # Withdraws funds from a virtual card.
    #
    # @param data [Hash] The withdrawal data.
    # @option data [Float, Integer] :amount The amount to withdraw.
    # @option data [String] :card_hash The hash of the card to withdraw from.
    # @return [Hash] The API response confirming the withdrawal.
    # @raise [Paychangu::InvalidInputError] if required parameters are missing.
    # @raise [Paychangu::AuthenticationError] if authentication fails.
    # @raise [Paychangu::APIError] for other API-related errors.
    def withdraw_card_funds(data = {})
      required_keys = %i[amount card_hash]
      validate_presence_of(data, required_keys)
      payload = withdraw_card_funds_payload(data)

      process_request(payload, API_ENDPOINTS[:withdraw], REQUEST_METHODS[:post])
    end

    # Retrieves the list of available airtime operators.
    #
    # @return [Hash] The API response containing the list of operators.
    # @raise [Paychangu::AuthenticationError] if authentication fails.
    # @raise [Paychangu::APIError] for other API-related errors.
    def airtime_operators
      process_request(nil, API_ENDPOINTS[:get_operators], REQUEST_METHODS[:get])
    end

    # Makes an airtime payment.
    #
    # @param data [Hash] The airtime payment data.
    # @option data [String] :operator The operator code.
    # @option data [Float, Integer] :amount The amount for the airtime purchase.
    # @option data [String] :phone The phone number to receive the airtime.
    # @option data [String] :callback_url The URL to send a POST request to upon completion.
    # @return [Hash] The API response confirming the airtime payment.
    # @raise [Paychangu::InvalidInputError] if required parameters are missing.
    # @raise [Paychangu::AuthenticationError] if authentication fails.
    # @raise [Paychangu::APIError] for other API-related errors.
    def airtime_payment(data = {})
      required_keys = %i[operator amount phone callback_url]
      validate_presence_of(data, required_keys)
      payload = create_airtime_payment_payload(data)

      process_request(payload, API_ENDPOINTS[:airtime_payment], REQUEST_METHODS[:post])
    end

    # Verifies a payment transaction.
    #
    # @param data [Hash] The verification data.
    # @option data [String] :tx_ref The transaction reference to verify.
    # @return [Hash] The API response containing the payment verification status.
    # @raise [Paychangu::AuthenticationError] if authentication fails.
    # @raise [Paychangu::APIError] for other API-related errors (e.g., if transaction not found, specific errors like NotFoundError may be raised).
    def verify_payment(data = {})
      process_request(nil, "#{API_ENDPOINTS[:verify_payment]}/#{data[:tx_ref]}", REQUEST_METHODS[:get])
    end

    private

    def paychangu_secret(secret_key)
      raise Paychangu::InvalidInputError, "Secret key not provided!" if secret_key.nil? || secret_key.to_s.empty?
      secret_key
    end

    def get_supported_currencies(currency)
      raise Paychangu::InvalidInputError, "#{currency} currency not supported!" unless SUPPORTED_CURRENCIES.include?(currency)
      currency
    end

    def get_card_supported_currencies(currency)
      raise Paychangu::InvalidInputError, "#{currency} currency not supported for cards!" unless SUPPORTED_CARD_CURRENCIES.include?(currency)
      currency
    end

    def create_link_payload(data)
      {
        amount: data[:amount],
        currency: get_supported_currencies(data[:currency]),
        email: data[:email],
        first_name: data[:first_name],
        last_name: data[:last_name],
        callback_url: data[:callback_url],
        return_url: data[:return_url],
        tx_ref: data[:tx_ref] || SecureRandom.hex(10),
        customization: customization(data), # customization already returns a Hash
        logo: data[:logo]
      } # Remove .to_json
    end

    def create_card_payload(data)
      {
        amount: data[:amount],
        currency: get_card_supported_currencies(data[:currency]),
        first_name: data[:first_name],
        last_name: data[:last_name],
        callback_url: data[:callback_url]
      } # Remove .to_json
    end

    def fund_card_payload(data)
      {
        amount: data[:amount],
        card_hash: data[:card_hash]
      } # Remove .to_json
    end

    def withdraw_card_funds_payload(data)
      {
        amount: data[:amount],
        card_hash: data[:card_hash]
      } # Remove .to_json
    end

    def customization(data)
      {
        title: data[:title],
        description: data[:description]
      } # This is fine, returns a Hash
    end

    def create_airtime_payment_payload(data)
      {
        operator: data[:operator],
        amount: data[:amount],
        phone: data[:phone],
        callback_url: data[:callback_url]
      } # Remove .to_json
    end

    def validate_presence_of(data, required_keys)
      required_keys.each do |key|
        if data[key].nil? || (data[key].is_a?(String) && data[key].strip.empty?)
          raise Paychangu::InvalidInputError, "Missing required parameter: #{key}"
        end
      end
    end

    def process_request(payload, path, method_verb)
      options = { headers: {} } # Initialize options with headers hash

      if payload && (method_verb == REQUEST_METHODS[:post] || method_verb == REQUEST_METHODS[:put])
        options[:body] = payload.to_json
        options[:headers]['Content-Type'] = 'application/json'
      end
      # No specific Content-Type logic for GET/DELETE here, HTTParty handles it.

      begin
        response = case method_verb
                   when REQUEST_METHODS[:post]
                     self.class.post("/#{path}", options)
                   when REQUEST_METHODS[:get]
                     # If 'payload' were to contain query parameters: options[:query] = payload
                     self.class.get("/#{path}", options)
                   when REQUEST_METHODS[:put]
                     self.class.put("/#{path}", options)
                   when REQUEST_METHODS[:delete]
                     # If 'payload' were to contain query parameters: options[:query] = payload
                     self.class.delete("/#{path}", options)
                   else
                     raise Paychangu::InvalidInputError, "Unsupported HTTP method: #{method_verb}"
                   end

        handle_response(response)
      rescue Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
        raise Paychangu::APIError, "Connection error: #{e.message}"
      end
    end

    def handle_response(response)
      parsed_response = response.parsed_response
      status_code = response.code

      # Log request and response for debugging (optional, consider a logger)
      # puts "PayChangu API Request: #{response.request.http_method} #{response.request.uri}"
      # puts "PayChangu API Response Status: #{status_code}"
      # puts "PayChangu API Response Body: #{parsed_response.inspect}"


      case status_code
      when 200..299
        parsed_response
      when 401
        raise Paychangu::AuthenticationError.new(
          (parsed_response&.is_a?(Hash) && parsed_response['message']) || "Authentication failed",
          response_body: parsed_response.to_s,
          status_code: status_code
        )
      when 400
        raise Paychangu::BadRequestError.new(
          (parsed_response&.is_a?(Hash) && parsed_response['message']) || "Bad request",
          response_body: parsed_response.to_s,
          status_code: status_code
        )
      when 404
        raise Paychangu::NotFoundError.new(
          (parsed_response&.is_a?(Hash) && parsed_response['message']) || "Resource not found",
          response_body: parsed_response.to_s,
          status_code: status_code
        )
      when 422
        raise Paychangu::UnprocessableEntityError.new(
          (parsed_response&.is_a?(Hash) && parsed_response['message']) || "Unprocessable entity",
          response_body: parsed_response.to_s,
          status_code: status_code
        )
      else # 5xx or other 4xx
        raise Paychangu::APIError.new(
          (parsed_response&.is_a?(Hash) && parsed_response['message']) || "API request failed",
          response_body: parsed_response.to_s,
          status_code: status_code
        )
      end
    end
  end
end
