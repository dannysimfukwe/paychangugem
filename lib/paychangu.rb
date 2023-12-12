# frozen_string_literal: true
require 'uri'
require 'json'
require 'net/http'
require 'securerandom'

require_relative "paychangu/version"
url = URI("https://api.paychangu.com/payment").freeze


module Paychangu
  def createPaymentLink(options = {}, url)
  end
end
