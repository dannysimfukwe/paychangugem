# frozen_string_literal: true

require "uri"
require "json"
require "net/http"
require "securerandom"

require_relative "paychangu/version"

module Paychangu
  # Main Payemnt Class
  class Payment
    API_URL = URI("https://api.paychangu.com/").freeze
    SUPPORTED_CURRENCIES = %w[MWK NGN ZAR GBP USD ZMW].freeze
    SUPPORTED_CARD_CURRENCIES = %w[USD].freeze

    API_ENDPOINTS = {
      payment: "payment",
      create_card: "virtual_card/create",
      fund_card: "virtual_card/fund",
      withdraw: "virtual_card/withdraw",
      get_operators: "bill_payment/get-operators",
      airtime_payment: "bill_payment/create"
    }.freeze

    REQUEST_METHODS = {
      post: "POST",
      get: "GET",
      puts: "PUT",
      delete: "DELETE"
    }.freeze

    def initialize(secret_key)
      @secret = paychangu_secret(secret_key)
    end

    def create_payment_link(data = {})
      payload = create_link_payload(data)

      process_request(payload, API_ENDPOINTS[:payment], REQUEST_METHODS[:post])
    end

    def create_virtual_card(data = {})
      payload = create_card_payload(data)

      process_request(payload, API_ENDPOINTS[:create_card], REQUEST_METHODS[:post])
    end

    def fund_card(data = {})
      payload = fund_card_payload(data)

      process_request(payload, API_ENDPOINTS[:fund_card], REQUEST_METHODS[:post])
    end

    def withdraw_card_funds(data = {})
      payload = withdraw_card_funds_payload(data)

      process_request(payload, API_ENDPOINTS[:withdraw], REQUEST_METHODS[:post])
    end

    def airtime_operators
      process_request(nil, API_ENDPOINTS[:get_operators], REQUEST_METHODS[:get])
    end

    private

    def paychangu_secret(secret_key)
      raise "Secret key not provided!" unless secret_key

      secret_key
    end

    def get_supported_currencies(currency)
      raise "#{currency} currency not supported!" unless SUPPORTED_CURRENCIES.include?(currency)

      currency
    end

    def get_card_supported_currencies(currency)
      raise "#{currency} currency not supported" unless SUPPORTED_CARD_CURRENCIES.include?(currency)

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
      }.to_json
    end

    def create_card_payload(data)
      {
        amount: data[:amount],
        currency: get_card_supported_currencies(data[:currency]),
        first_name: data[:first_name],
        last_name: data[:last_name],
        callback_url: data[:callback_url]
      }.to_json
    end

    def fund_card_payload(data)
      {
        amount: data[:amount],
        card_hash: data[:card_hash]
      }.to_json
    end

    def withdraw_card_funds_payload(data)
      {
        amount: data[:amount],
        card_hash: data[:card_hash]
      }.to_json
    end

    def customization(data)
      {
        title: data[:title],
        description: data[:description]
      }
    end

    def process_request(payload, path, method)
      http = Net::HTTP.new(API_URL.host, API_URL.port)
      http.use_ssl = true

      case method
      when "POST"
        request = Net::HTTP::Post.new("#{API_URL}#{path}")
        request["accept"] = "application/json"
        request["Authorization"] = "Bearer #{@secret}"
        request["content-type"] = "application/json"
        request.body = payload
      when "GET"
        request = Net::HTTP::Get.new("#{API_URL}#{path}")
        request["accept"] = "application/json"
        request["Authorization"] = "Bearer #{@secret}"
        request["content-type"] = "application/json"
      end

      response = http.request(request)
      JSON.parse(response.body)
    end
  end
end
