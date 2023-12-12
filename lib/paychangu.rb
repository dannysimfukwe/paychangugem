# frozen_string_literal: true
require 'uri'
require 'json'
require 'net/http'
require 'securerandom'

require_relative "paychangu/version"

module Paychangu
  class Payment
    payment_url = URI("https://api.paychangu.com/").freeze
    supported_currencies =  ['MWK', 'NGN', 'ZAR', 'GBP', 'USD', 'ZMW'].freeze

    def initialize(secret_key, supported_currencies, payment_url)
      @secret = set_secret(secret_key)
      @url = payment_url
      @supported_currencies = supported_currencies
    end

    def create_payment_link(data = {})
      path = "payment"
      http = Net::HTTP.new(@url.host, @url.port)
      http.use_ssl = true

      payload = {
        :amount => data[:amount],
        :currency => get_supported_currencies(data[:currency]),
        :email => data[:email],
        :first_name => data[:first_name],
        :last_name => data[:last_name],
        :callback_url => data[:callback_url],
        :return_url => data[:return_url],
        :tx_ref => data[:tx_ref] || SecureRandom.hex(10),
        :customization => {
            :title => data[:title],
            :description => data[:description]
            },
        :logo => data[:logo]
    }.to_json

      request = Net::HTTP::Post.new(@url + "/#{path}")
      request["accept"] = 'application/json'
      request["Authorization"] =  "Bearer #{@secret}"
      request["content-type"] = 'application/json'
      request.body = payload

      response = http.request(request)
      response.read_body
    end

    def set_secret(secret_key)
      raise "Secret key not provided!" unless secret_key
      secret_key
    end

    def get_supported_currencies(currency) 
      raise "currency list not provided!" unless @supported_currencies.include?(currency)

      currency
    end
  end
end
