# frozen_string_literal: true

require "spec_helper"
require "paychangu"

RSpec.describe Paychangu::Payment do
  let(:secret_key) { "Test" }

  describe "#initialize" do
    it "has a version number" do
      expect(Paychangu::VERSION).not_to be nil
    end
    it "initializes the Payment class with a secret key" do
      payment = described_class.new(secret_key)
      expect(payment.instance_variable_get(:@secret)).to eq(secret_key)
    end

    it "raises an error if no secret key is provided" do
      expect { described_class.new(nil) }.to raise_error(RuntimeError, "Secret key not provided!")
    end
  end

  describe "#create_payment_link" do
    it "creates a payment link" do
      payment = described_class.new(secret_key)
      data = {
        amount: 100,
        currency: "USD",
        email: "test@example.com",
        first_name: "John",
        last_name: "Doe",
        callback_url: "https://example.com/callback",
        return_url: "https://example.com/return",
        tx_ref: "txn_123456",
        title: "Test Payment",
        description: "This is a test payment",
        logo: "https://example.com/logo.png"
      }

      expect { payment.create_payment_link(data) }.not_to raise_error
    end

    it "raises an error if the payment currency is not valid" do
      payment = described_class.new(secret_key)
      data = {
        amount: 100,
        currency: "USD1",
        email: "test@example.com",
        first_name: "John",
        last_name: "Doe",
        callback_url: "https://example.com/callback",
        return_url: "https://example.com/return",
        tx_ref: "txn_123456",
        title: "Test Payment",
        description: "This is a test payment",
        logo: "https://example.com/logo.png"
      }

      expect { payment.create_payment_link(data) }.to raise_error(RuntimeError, "USD1 currency not supported!")
    end
  end
end
