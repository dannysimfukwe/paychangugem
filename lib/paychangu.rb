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
      verify_payment: "verify-payment",
      direct_charge_momo: "mobilemoney",
      direct_charge_bank: "bank-transfer",
      get_single_charge_details: "get-single-charge-details",
      disburse_momo: "disbursements/mobile-money",
      disburse_bank: "disbursements/bank",
      get_payout_operators: "disbursements/get-operators",
      get_payout_banks: "disbursements/banks"
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

    # Initiates a direct mobile money charge.
    #
    # @param data [Hash] The mobile money charge data.
    # @option data [Float, Integer] :amount The amount for the charge.
    # @option data [String] :currency The currency code (e.g., "MWK", "USD"). See {SUPPORTED_CURRENCIES}.
    # @option data [String] :email The customer's email address.
    # @option data [String] :phone_number The customer's phone number.
    # @option data [String] :network The mobile money network provider.
    # @option data [String] :first_name The customer's first name.
    # @option data [String] :last_name The customer's last name.
    # @option data [String] :callback_url The URL to send a POST request to upon charge completion.
    # @option data [String] :return_url The URL to redirect the user to after charge completion.
    # @option data [String] :tx_ref (optional) Unique transaction reference. Auto-generated if not provided.
    # @return [Hash] The API response containing the charge details.
    # @raise [Paychangu::InvalidInputError] if required parameters are missing or invalid (e.g., unsupported currency).
    # @raise [Paychangu::AuthenticationError] if authentication fails.
    # @raise [Paychangu::APIError] for other API-related errors.
    def direct_charge_mobile_money(data = {})
      required_keys = %i[amount currency email phone_number network first_name last_name callback_url return_url]
      validate_presence_of(data, required_keys)

      payload = {
        amount: data[:amount],
        currency: get_supported_currencies(data[:currency]),
        email: data[:email],
        phone_number: data[:phone_number],
        network: data[:network],
        first_name: data[:first_name],
        last_name: data[:last_name],
        callback_url: data[:callback_url],
        return_url: data[:return_url],
        tx_ref: data[:tx_ref] || SecureRandom.hex(10)
      }

      process_request(payload, API_ENDPOINTS[:direct_charge_momo], REQUEST_METHODS[:post])
    end

    # Initiates a direct bank transfer.
    #
    # @param data [Hash] The bank transfer data.
    # @option data [Float, Integer] :amount The amount for the transfer.
    # @option data [String] :currency The currency code (e.g., "MWK", "USD"). See {SUPPORTED_CURRENCIES}.
    # @option data [String] :email The customer's email address.
    # @option data [String] :bank_code The customer's bank code.
    # @option data [String] :account_number The customer's bank account number.
    # @option data [String] :first_name The customer's first name.
    # @option data [String] :last_name The customer's last name.
    # @option data [String] :callback_url The URL to send a POST request to upon transfer completion.
    # @option data [String] :return_url The URL to redirect the user to after transfer completion.
    # @option data [String] :tx_ref (optional) Unique transaction reference. Auto-generated if not provided.
    # @return [Hash] The API response containing the transfer details.
    # @raise [Paychangu::InvalidInputError] if required parameters are missing or invalid (e.g., unsupported currency).
    # @raise [Paychangu::AuthenticationError] if authentication fails.
    # @raise [Paychangu::APIError] for other API-related errors.
    def direct_charge_bank_transfer(data = {})
      required_keys = %i[amount currency email bank_code account_number first_name last_name callback_url return_url]
      validate_presence_of(data, required_keys)

      payload = {
        amount: data[:amount],
        currency: get_supported_currencies(data[:currency]),
        email: data[:email],
        bank_code: data[:bank_code],
        account_number: data[:account_number],
        first_name: data[:first_name],
        last_name: data[:last_name],
        callback_url: data[:callback_url],
        return_url: data[:return_url],
        tx_ref: data[:tx_ref] || SecureRandom.hex(10)
      }

      process_request(payload, API_ENDPOINTS[:direct_charge_bank], REQUEST_METHODS[:post])
    end

    # Retrieves the details of a specific charge transaction.
    #
    # @param data [Hash] The data containing the transaction reference.
    # @option data [String] :tx_ref The transaction reference to retrieve details for.
    # @return [Hash] The API response containing the charge details.
    # @raise [Paychangu::InvalidInputError] if the `tx_ref` parameter is missing.
    # @raise [Paychangu::AuthenticationError] if authentication fails.
    # @raise [Paychangu::APIError] for other API-related errors (e.g., if transaction not found).
    def get_charge_details(data = {})
      required_keys = %i[tx_ref]
      validate_presence_of(data, required_keys)

      path = "#{API_ENDPOINTS[:get_single_charge_details]}/#{data[:tx_ref]}"
      process_request(nil, path, REQUEST_METHODS[:get])
    end

    # Retrieves the list of available mobile money operators for payouts.
    #
    # @return [Hash] The API response containing the list of mobile money operators.
    # @raise [Paychangu::AuthenticationError] if authentication fails.
    # @raise [Paychangu::APIError] for other API-related errors.
    def get_payout_mobile_operators
      process_request(nil, API_ENDPOINTS[:get_payout_operators], REQUEST_METHODS[:get])
    end

    # Retrieves the list of available banks for payouts.
    #
    # @return [Hash] The API response containing the list of banks.
    # @raise [Paychangu::AuthenticationError] if authentication fails.
    # @raise [Paychangu::APIError] for other API-related errors.
    def get_payout_banks
      process_request(nil, API_ENDPOINTS[:get_payout_banks], REQUEST_METHODS[:get])
    end

    # Disburses funds to a mobile money account.
    #
    # @param data [Hash] The disbursement data.
    # @option data [Float, Integer] :amount The amount to disburse.
    # @option data [String] :currency The currency code (e.g., "MWK", "USD"). See {SUPPORTED_CURRENCIES}.
    # @option data [String] :phone_number The recipient's phone number.
    # @option data [String] :network The mobile money network provider.
    # @option data [String] :reason The reason for the disbursement.
    # @option data [String] :reference Unique client-provided reference for the transaction.
    # @return [Hash] The API response confirming the disbursement.
    # @raise [Paychangu::InvalidInputError] if required parameters are missing or invalid.
    # @raise [Paychangu::AuthenticationError] if authentication fails.
    # @raise [Paychangu::APIError] for other API-related errors.
    def disburse_to_mobile_money(data = {})
      required_keys = %i[amount currency phone_number network reason reference]
      validate_presence_of(data, required_keys)

      payload = {
        amount: data[:amount],
        currency: get_supported_currencies(data[:currency]),
        phone_number: data[:phone_number],
        network: data[:network],
        reason: data[:reason],
        reference: data[:reference]
      }
      process_request(payload, API_ENDPOINTS[:disburse_momo], REQUEST_METHODS[:post])
    end

    # Disburses funds to a bank account.
    #
    # @param data [Hash] The disbursement data.
    # @option data [Float, Integer] :amount The amount to disburse.
    # @option data [String] :currency The currency code (e.g., "MWK", "USD"). See {SUPPORTED_CURRENCIES}.
    # @option data [String] :bank_code The recipient's bank code.
    # @option data [String] :account_number The recipient's bank account number.
    # @option data [String] :account_name The recipient's bank account name.
    # @option data [String] :reason The reason for the disbursement.
    # @option data [String] :reference Unique client-provided reference for the transaction.
    # @return [Hash] The API response confirming the disbursement.
    # @raise [Paychangu::InvalidInputError] if required parameters are missing or invalid.
    # @raise [Paychangu::AuthenticationError] if authentication fails.
    # @raise [Paychangu::APIError] for other API-related errors.
    def disburse_to_bank_account(data = {})
      required_keys = %i[amount currency bank_code account_number account_name reason reference]
      validate_presence_of(data, required_keys)

      payload = {
        amount: data[:amount],
        currency: get_supported_currencies(data[:currency]),
        bank_code: data[:bank_code],
        account_number: data[:account_number],
        account_name: data[:account_name],
        reason: data[:reason],
        reference: data[:reference]
      }
      process_request(payload, API_ENDPOINTS[:disburse_bank], REQUEST_METHODS[:post])
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
        customization: customization(data),
        logo: data[:logo]
      }
    end

    def create_card_payload(data)
      {
        amount: data[:amount],
        currency: get_card_supported_currencies(data[:currency]),
        first_name: data[:first_name],
        last_name: data[:last_name],
        callback_url: data[:callback_url]
      }
    end

    def fund_card_payload(data)
      {
        amount: data[:amount],
        card_hash: data[:card_hash]
      }
    end

    def withdraw_card_funds_payload(data)
      {
        amount: data[:amount],
        card_hash: data[:card_hash]
      }
    end

    def customization(data)
      {
        title: data[:title],
        description: data[:description]
      }
    end

    def create_airtime_payment_payload(data)
      {
        operator: data[:operator],
        amount: data[:amount],
        phone: data[:phone],
        callback_url: data[:callback_url]
      }
    end

    def validate_presence_of(data, required_keys)
      required_keys.each do |key|
        if data[key].nil? || (data[key].is_a?(String) && data[key].strip.empty?)
          raise Paychangu::InvalidInputError, "Missing required parameter: #{key}"
        end
      end
    end

    def process_request(payload, path, method_verb)
      options = { headers: {} }

      if payload && (method_verb == REQUEST_METHODS[:post] || method_verb == REQUEST_METHODS[:put])
        options[:body] = payload.to_json
        options[:headers]['Content-Type'] = 'application/json'
      end

      begin
        response = case method_verb
                   when REQUEST_METHODS[:post]
                     self.class.post("/#{path}", options)
                   when REQUEST_METHODS[:get]
                     self.class.get("/#{path}", options)
                   when REQUEST_METHODS[:put]
                     self.class.put("/#{path}", options)
                   when REQUEST_METHODS[:delete]
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
