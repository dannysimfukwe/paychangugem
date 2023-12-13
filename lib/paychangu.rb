# frozen_string_literal: true

require "uri"
require "json"
require "net/http"
require "securerandom"

require_relative "paychangu/version"

module Paychangu
  class Payment
    # We need to provide the Paychangu secret key

    def initialize(secret_key)
      @secret = paychangu_secret(secret_key)
      @url = URI("https://api.paychangu.com/").freeze
      @supported_currencies = %w[MWK NGN ZAR GBP USD ZMW].freeze
      @card_currencies = %w[USD].freeze
    end

    def create_payment_link(data = {})
      path = "payment"

      payload = link_payload(data)

      process_request(payload, path)
    end

    def create_virtual_card(data = {})
      path = "virtual_card/create"

      payload = card_payload(data)

      process_request(payload, path)
    end

    private

    def paychangu_secret(secret_key)
      raise "Secret key not provided!" unless secret_key

      secret_key
    end

    def get_supported_currencies(currency)
      raise "#{currency} currency not supported!" unless @supported_currencies.include?(currency)

      currency
    end

    def get_card_supported_currencies(currency)
      raise "#{currency} currency not supported" unless @card_currencies.include?(currency)

      currency
    end

    def link_payload(data)
      {
        amount: data[:amount],
        currency: get_supported_currencies(data[:currency]),
        email: data[:email],
        first_name: data[:first_name],
        last_name: data[:last_name],
        callback_url: data[:callback_url],
        return_url: data[:return_url],
        tx_ref: data[:tx_ref] || SecureRandom.hex(10),
        customization: {
          title: data[:title],
          description: data[:description]
        },
        logo: data[:logo]
      }.to_json
    end

    def card_payload(data)
      {
        amount: data[:amount],
        currency: get_card_supported_currencies(data[:currency]),
        first_name: data[:first_name],
        last_name: data[:last_name],
        callback_url: data[:callback_url]
      }.to_json
    end

    def process_request(payload, path)
      http = Net::HTTP.new(@url.host, @url.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(@url + "/#{path}")
      request["accept"] = "application/json"
      request["Authorization"] = "Bearer #{@secret}"
      request["content-type"] = "application/json"
      request.body = payload

      response = http.request(request)
      response.read_body
    end
  end
end
