# frozen_string_literal: true

require "spec_helper"
require 'paychangu/errors' # Required for explicit error type checking

RSpec.describe Paychangu::Payment do
  let(:secret_key) { "test_secret_key" }
  let(:base_api_url) { "https://api.paychangu.com" }
  let(:payment) { described_class.new(secret_key) }

  # Helper to stub requests easily
  def stub_paychangu_request(method, path, request_body: nil, response_body: {}, status: 200)
    expected_headers = {
      'Accept'=>'application/json',
      'Authorization'=>"Bearer #{secret_key}"
    }
    # Add Content-Type only if there's a request body AND it's a POST/PUT (Ruby symbols for methods)
    # HTTParty default methods are get, post, put, delete, patch, head, options
    if request_body && (method == :post || method == :put)
      expected_headers['Content-Type'] = 'application/json'
    end

    stub_request(method, "#{base_api_url}/#{path}")
      .with(
        headers: expected_headers,
        body: request_body
      )
      .to_return(status: status, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  describe "#initialize" do
    it "has a version number" do # This test might be better in a general gem spec
      expect(Paychangu::VERSION).not_to be nil
    end

    it "initializes the Payment class with a secret key" do
      expect(payment.instance_variable_get(:@secret)).to eq(secret_key)
    end

    it "raises Paychangu::InvalidInputError if no secret key is provided" do
      expect { described_class.new(nil) }.to raise_error(Paychangu::InvalidInputError, "Secret key not provided!")
      expect { described_class.new('') }.to raise_error(Paychangu::InvalidInputError, "Secret key not provided!")
    end
  end

  describe "#create_payment_link" do
    let(:valid_payload) do
      {
        amount: 100, currency: "MWK", email: "test@example.com", first_name: "John",
        last_name: "Doe", callback_url: "cb_url", return_url: "ret_url",
        tx_ref: "test_tx_ref", title: "Test Title", description: "Test Desc", logo: "logo.png"
      }
    end
    let(:customization_data) { { title: valid_payload[:title], description: valid_payload[:description] } }
    let(:expected_request_body) do
        valid_payload.except(:title, :description).merge(customization: customization_data)
    end

    it "creates a payment link successfully" do
      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:payment],
                             request_body: expected_request_body,
                             response_body: { status: "success", data: { link: "payment_link" } })

      response = payment.create_payment_link(valid_payload)
      expect(response["status"]).to eq("success")
      expect(response["data"]["link"]).to eq("payment_link")
    end

    it "raises Paychangu::InvalidInputError for unsupported currency" do
      invalid_payload = valid_payload.merge(currency: "XYZ")
      expect { payment.create_payment_link(invalid_payload) }
        .to raise_error(Paychangu::InvalidInputError, "XYZ currency not supported!")
    end

    it "raises Paychangu::APIError for API failures" do
      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:payment],
                             request_body: expected_request_body,
                             response_body: { message: "Internal server error" }, status: 500)
      expect { payment.create_payment_link(valid_payload) }
        .to raise_error(Paychangu::APIError, /Internal server error.*Status: 500/)
    end

     it "uses a new tx_ref if none is provided" do
      payload_without_tx_ref = valid_payload.except(:tx_ref)
      allow(SecureRandom).to receive(:hex).with(10).and_return("mocked_tx_ref")
      expected_body_with_mocked_tx_ref = payload_without_tx_ref.except(:title, :description)
                                          .merge(customization: customization_data, tx_ref: "mocked_tx_ref")

      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:payment],
                             request_body: expected_body_with_mocked_tx_ref,
                             response_body: { status: "success" })
      payment.create_payment_link(payload_without_tx_ref)
    end

    it "creates a payment link successfully with a different valid currency (NGN)" do
      ngn_payload = valid_payload.merge(currency: "NGN")
      expected_ngn_request_body = expected_request_body.merge(currency: "NGN")
      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:payment],
                             request_body: expected_ngn_request_body,
                             response_body: { status: "success", data: { link: "payment_link_ngn" } })

      response = payment.create_payment_link(ngn_payload)
      expect(response["status"]).to eq("success")
      expect(response["data"]["link"]).to eq("payment_link_ngn")
    end

    it "creates a payment link successfully when optional parameters (title, description, logo) are not provided" do
      payload_without_optionals = valid_payload.except(:title, :description, :logo)
      # Customization will be an empty hash or have nils if not provided.
      # The create_link_payload method creates customization like:
      # { title: data[:title], description: data[:description] }
      # So, if title and description are not in data, customization becomes { title: nil, description: nil }
      expected_customization_without_optionals = { title: nil, description: nil }
      expected_request_body_without_optionals = payload_without_optionals
                                                  .except(:title, :description) # These were already removed for base expected_request_body
                                                  .merge(customization: expected_customization_without_optionals, logo: nil)


      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:payment],
                             request_body: expected_request_body_without_optionals,
                             response_body: { status: "success" })
      payment.create_payment_link(payload_without_optionals)
    end

    context "input validations" do
      let(:base_payload) do
        {
          amount: 100, currency: "MWK", email: "test@example.com", first_name: "John",
          last_name: "Doe", callback_url: "cb_url", return_url: "ret_url",
          tx_ref: "test_tx_ref", title: "Test Title", description: "Test Desc", logo: "logo.png"
        }
      end

      %i[amount currency email first_name last_name callback_url return_url].each do |required_key|
        it "raises an error if #{required_key} is missing" do
          payload = base_payload.dup
          payload.delete(required_key) # Test for key completely missing
          expect { payment.create_payment_link(payload) }
            .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
        end

        it "raises an error if #{required_key} is nil" do
          payload = base_payload.merge(required_key => nil) # Test for key present but nil
          expect { payment.create_payment_link(payload) }
            .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
        end

        # Optional: Test for empty string if applicable to your validation logic for string fields
        if %i[email first_name last_name callback_url return_url].include?(required_key)
          it "raises an error if #{required_key} is an empty string" do
            payload = base_payload.merge(required_key => "") # Test for key present but empty string
            expect { payment.create_payment_link(payload) }
              .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")

            payload_with_whitespace = base_payload.merge(required_key => "   ") # Test for key present but whitespace string
            expect { payment.create_payment_link(payload_with_whitespace) }
              .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
          end
        end
      end
    end
  end

  describe "#create_virtual_card" do
    let(:valid_payload) { { amount: 50, currency: "USD", first_name: "Jane", last_name: "Doe", callback_url: "cb_url" } }

    it "creates a virtual card successfully with USD currency" do # Explicitly testing valid card currency
      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:create_card],
                             request_body: valid_payload, # valid_payload already uses USD
                             response_body: { status: "success", data: { card_id: "card_123_usd" } })
      response = payment.create_virtual_card(valid_payload)
      expect(response["status"]).to eq("success")
      expect(response["data"]["card_id"]).to eq("card_123_usd")
    end

    it "raises Paychangu::InvalidInputError for unsupported card currency" do
      invalid_payload = valid_payload.merge(currency: "MWK")
      expect { payment.create_virtual_card(invalid_payload) }
        .to raise_error(Paychangu::InvalidInputError, "MWK currency not supported for cards!")
    end

    it "raises Paychangu::BadRequestError for API failures with 400 status" do
      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:create_card],
                             request_body: valid_payload,
                             response_body: { message: "Card creation failed" }, status: 400)
      expect { payment.create_virtual_card(valid_payload) }
        .to raise_error(Paychangu::BadRequestError, /Card creation failed.*Status: 400/)
    end

    context "input validations" do
      let(:base_payload) { { amount: 50, currency: "USD", first_name: "Jane", last_name: "Doe", callback_url: "cb_url" } }

      %i[amount currency first_name last_name callback_url].each do |required_key|
        it "raises an error if #{required_key} is missing" do
          payload = base_payload.dup
          payload.delete(required_key)
          expect { payment.create_virtual_card(payload) }
            .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
        end

        it "raises an error if #{required_key} is nil" do
          payload = base_payload.merge(required_key => nil)
          expect { payment.create_virtual_card(payload) }
            .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
        end

        if %i[currency first_name last_name callback_url].include?(required_key)
          it "raises an error if #{required_key} is an empty string" do
            payload = base_payload.merge(required_key => "")
            expect { payment.create_virtual_card(payload) }
              .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
            payload_ws = base_payload.merge(required_key => "   ")
            expect { payment.create_virtual_card(payload_ws) }
              .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
          end
        end
      end
    end
  end

  describe "#fund_card" do
    let(:valid_payload) { { amount: 100, card_hash: "hash123" } }
    it "funds a card successfully" do
      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:fund_card],
                             request_body: valid_payload,
                             response_body: { status: "success" })
      expect(payment.fund_card(valid_payload)["status"]).to eq("success")
    end
     it "raises Paychangu::APIError for API failures" do
      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:fund_card],
                             request_body: valid_payload,
                             response_body: { message: "Funding failed" }, status: 500)
      expect { payment.fund_card(valid_payload) }
        .to raise_error(Paychangu::APIError, /Funding failed.*Status: 500/)
    end

    context "input validations" do
      let(:base_payload) { { amount: 100, card_hash: "hash123" } }

      %i[amount card_hash].each do |required_key|
        it "raises an error if #{required_key} is missing" do
          payload = base_payload.dup
          payload.delete(required_key)
          expect { payment.fund_card(payload) }
            .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
        end

        it "raises an error if #{required_key} is nil" do
          payload = base_payload.merge(required_key => nil)
          expect { payment.fund_card(payload) }
            .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
        end

        if %i[card_hash].include?(required_key) # card_hash is a string
          it "raises an error if #{required_key} is an empty string" do
            payload = base_payload.merge(required_key => "")
            expect { payment.fund_card(payload) }
              .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
            payload_ws = base_payload.merge(required_key => "   ")
            expect { payment.fund_card(payload_ws) }
              .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
          end
        end
      end
    end
  end

  describe "#withdraw_card_funds" do
    let(:valid_payload) { { amount: 50, card_hash: "hash123" } }
    it "withdraws card funds successfully" do
      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:withdraw],
                             request_body: valid_payload,
                             response_body: { status: "success" })
      expect(payment.withdraw_card_funds(valid_payload)["status"]).to eq("success")
    end
    it "raises Paychangu::APIError for API failures" do
      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:withdraw],
                             request_body: valid_payload,
                             response_body: { message: "Withdrawal failed" }, status: 500)
      expect { payment.withdraw_card_funds(valid_payload) }
        .to raise_error(Paychangu::APIError, /Withdrawal failed.*Status: 500/)
    end

    context "input validations" do
      let(:base_payload) { { amount: 50, card_hash: "hash123" } }

      %i[amount card_hash].each do |required_key|
        it "raises an error if #{required_key} is missing" do
          payload = base_payload.dup
          payload.delete(required_key)
          expect { payment.withdraw_card_funds(payload) }
            .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
        end

        it "raises an error if #{required_key} is nil" do
          payload = base_payload.merge(required_key => nil)
          expect { payment.withdraw_card_funds(payload) }
            .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
        end

        if %i[card_hash].include?(required_key) # card_hash is a string
          it "raises an error if #{required_key} is an empty string" do
            payload = base_payload.merge(required_key => "")
            expect { payment.withdraw_card_funds(payload) }
              .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
            payload_ws = base_payload.merge(required_key => "   ")
            expect { payment.withdraw_card_funds(payload_ws) }
              .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
          end
        end
      end
    end
  end

  describe "#airtime_operators" do
    it "gets airtime operators successfully" do
      stub_paychangu_request(:get, Paychangu::Payment::API_ENDPOINTS[:get_operators],
                             response_body: { status: "success", data: ["Op1", "Op2"] })
      response = payment.airtime_operators
      expect(response["status"]).to eq("success")
      expect(response["data"]).to include("Op1")
    end
     it "raises Paychangu::APIError for API failures" do
      stub_paychangu_request(:get, Paychangu::Payment::API_ENDPOINTS[:get_operators],
                             response_body: { message: "Failed to fetch" }, status: 503)
      expect { payment.airtime_operators }
        .to raise_error(Paychangu::APIError, /Failed to fetch.*Status: 503/)
    end
  end

  describe "#airtime_payment" do
    let(:valid_payload) { { operator: "Op1", amount: 10, phone: "12345", callback_url: "cb_url" } }
    it "makes an airtime payment successfully" do
      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:airtime_payment],
                             request_body: valid_payload,
                             response_body: { status: "success" })
      expect(payment.airtime_payment(valid_payload)["status"]).to eq("success")
    end
    it "raises Paychangu::BadRequestError for API failures with 400 status" do
      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:airtime_payment],
                             request_body: valid_payload,
                             response_body: { message: "Airtime purchase failed" }, status: 400)
      expect { payment.airtime_payment(valid_payload) }
        .to raise_error(Paychangu::BadRequestError, /Airtime purchase failed.*Status: 400/)
    end

    context "input validations" do
      let(:base_payload) { { operator: "Op1", amount: 10, phone: "12345", callback_url: "cb_url" } }

      %i[operator amount phone callback_url].each do |required_key|
        it "raises an error if #{required_key} is missing" do
          payload = base_payload.dup
          payload.delete(required_key)
          expect { payment.airtime_payment(payload) }
            .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
        end

        it "raises an error if #{required_key} is nil" do
          payload = base_payload.merge(required_key => nil)
          expect { payment.airtime_payment(payload) }
            .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
        end

        if %i[operator phone callback_url].include?(required_key) # String fields
          it "raises an error if #{required_key} is an empty string" do
            payload = base_payload.merge(required_key => "")
            expect { payment.airtime_payment(payload) }
              .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
            payload_ws = base_payload.merge(required_key => "   ")
            expect { payment.airtime_payment(payload_ws) }
              .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{required_key}")
          end
        end
      end
    end
  end

  describe "#verify_payment" do
    let(:tx_ref) { "ref123" }
    it "verifies a payment successfully" do
      stub_paychangu_request(:get, "#{Paychangu::Payment::API_ENDPOINTS[:verify_payment]}/#{tx_ref}",
                             response_body: { status: "success", data: { state: "PAID" } })
      response = payment.verify_payment(tx_ref: tx_ref)
      expect(response["status"]).to eq("success")
      expect(response["data"]["state"]).to eq("PAID")
    end

    it "raises Paychangu::NotFoundError for API failures with 404 status" do
      stub_paychangu_request(:get, "#{Paychangu::Payment::API_ENDPOINTS[:verify_payment]}/#{tx_ref}",
                             response_body: { message: "Verification failed" }, status: 404)
      expect { payment.verify_payment(tx_ref: tx_ref) }
        .to raise_error(Paychangu::NotFoundError, /Verification failed.*Status: 404/)
    end

    it "raises Paychangu::AuthenticationError for 401 status" do
      stub_paychangu_request(:get, "#{Paychangu::Payment::API_ENDPOINTS[:verify_payment]}/#{tx_ref}",
                             response_body: { message: "Invalid token" }, status: 401)
      expect { payment.verify_payment(tx_ref: tx_ref) }
        .to raise_error(Paychangu::AuthenticationError, /Invalid token.*Status: 401/)
    end
  end

  describe "#direct_charge_mobile_money" do
    let(:valid_payload_data) do
      {
        amount: 500,
        currency: "MWK",
        email: "customer@example.com",
        phone_number: "0999000000",
        network: "AIRTEL",
        first_name: "Test",
        last_name: "User",
        callback_url: "https://example.com/callback",
        return_url: "https://example.com/return",
        tx_ref: "test-momo-tx-ref"
      }
    end
    let(:expected_request_body) { valid_payload_data }

    it "initiates a mobile money direct charge successfully" do
      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:direct_charge_momo],
                             request_body: expected_request_body,
                             response_body: { status: "success", message: "Charge initiated" })
      response = payment.direct_charge_mobile_money(valid_payload_data)
      expect(response["status"]).to eq("success")
      expect(response["message"]).to eq("Charge initiated")
    end

    it "uses a new tx_ref if none is provided" do
      payload_without_tx_ref = valid_payload_data.except(:tx_ref)
      allow(SecureRandom).to receive(:hex).with(10).and_return("mocked_momo_tx_ref")
      expected_body_with_mocked_tx_ref = payload_without_tx_ref.merge(tx_ref: "mocked_momo_tx_ref")

      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:direct_charge_momo],
                             request_body: expected_body_with_mocked_tx_ref,
                             response_body: { status: "success" })
      payment.direct_charge_mobile_money(payload_without_tx_ref)
    end

    context "input validations" do
      let(:required_keys) { %i[amount currency email phone_number network first_name last_name callback_url return_url] }

      required_keys.each do |key|
        it "raises InvalidInputError if #{key} is missing" do
          invalid_payload = valid_payload_data.dup
          invalid_payload.delete(key)
          expect { payment.direct_charge_mobile_money(invalid_payload) }
            .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{key}")
        end

        it "raises InvalidInputError if #{key} is nil" do
          expect { payment.direct_charge_mobile_money(valid_payload_data.merge(key => nil)) }
            .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{key}")
        end

        if valid_payload_data[key].is_a?(String)
          it "raises InvalidInputError if #{key} is an empty or whitespace string" do
            expect { payment.direct_charge_mobile_money(valid_payload_data.merge(key => "")) }
              .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{key}")
            expect { payment.direct_charge_mobile_money(valid_payload_data.merge(key => "   ")) }
              .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{key}")
          end
        end
      end

      it "raises InvalidInputError for unsupported currency" do
        invalid_payload = valid_payload_data.merge(currency: "XYZ")
        expect { payment.direct_charge_mobile_money(invalid_payload) }
          .to raise_error(Paychangu::InvalidInputError, "XYZ currency not supported!")
      end
    end

    context "API error handling" do
      it "raises AuthenticationError for 401 status" do
        stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:direct_charge_momo],
                               request_body: expected_request_body,
                               response_body: { message: "Auth error" }, status: 401)
        expect { payment.direct_charge_mobile_money(valid_payload_data) }
          .to raise_error(Paychangu::AuthenticationError, /Auth error.*Status: 401/)
      end

      it "raises BadRequestError for 400 status" do
        stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:direct_charge_momo],
                               request_body: expected_request_body,
                               response_body: { message: "Bad request" }, status: 400)
        expect { payment.direct_charge_mobile_money(valid_payload_data) }
          .to raise_error(Paychangu::BadRequestError, /Bad request.*Status: 400/)
      end

       it "raises UnprocessableEntityError for 422 status" do
        stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:direct_charge_momo],
                               request_body: expected_request_body,
                               response_body: { message: "Unprocessable" }, status: 422)
        expect { payment.direct_charge_mobile_money(valid_payload_data) }
          .to raise_error(Paychangu::UnprocessableEntityError, /Unprocessable.*Status: 422/)
      end

      it "raises APIError for other server errors (e.g., 500)" do
        stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:direct_charge_momo],
                               request_body: expected_request_body,
                               response_body: { message: "Server error" }, status: 500)
        expect { payment.direct_charge_mobile_money(valid_payload_data) }
          .to raise_error(Paychangu::APIError, /Server error.*Status: 500/)
      end
    end
  end

  describe "#direct_charge_bank_transfer" do
    let(:valid_payload_data) do
      {
        amount: 10000,
        currency: "NGN",
        email: "customer@example.com",
        bank_code: "058", # Example bank code
        account_number: "0123456789",
        first_name: "Test",
        last_name: "User",
        callback_url: "https://example.com/callback",
        return_url: "https://example.com/return",
        tx_ref: "test-bank-tx-ref"
      }
    end
    let(:expected_request_body) { valid_payload_data }

    it "initiates a bank transfer direct charge successfully" do
      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:direct_charge_bank],
                             request_body: expected_request_body,
                             response_body: { status: "success", message: "Bank charge initiated" })
      response = payment.direct_charge_bank_transfer(valid_payload_data)
      expect(response["status"]).to eq("success")
      expect(response["message"]).to eq("Bank charge initiated")
    end

    it "uses a new tx_ref if none is provided" do
      payload_without_tx_ref = valid_payload_data.except(:tx_ref)
      allow(SecureRandom).to receive(:hex).with(10).and_return("mocked_bank_tx_ref")
      expected_body_with_mocked_tx_ref = payload_without_tx_ref.merge(tx_ref: "mocked_bank_tx_ref")

      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:direct_charge_bank],
                             request_body: expected_body_with_mocked_tx_ref,
                             response_body: { status: "success" })
      payment.direct_charge_bank_transfer(payload_without_tx_ref)
    end

    context "input validations" do
      let(:required_keys) { %i[amount currency email bank_code account_number first_name last_name callback_url return_url] }

      required_keys.each do |key|
        it "raises InvalidInputError if #{key} is missing" do
          invalid_payload = valid_payload_data.dup
          invalid_payload.delete(key)
          expect { payment.direct_charge_bank_transfer(invalid_payload) }
            .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{key}")
        end

        it "raises InvalidInputError if #{key} is nil" do
          expect { payment.direct_charge_bank_transfer(valid_payload_data.merge(key => nil)) }
            .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{key}")
        end

        if valid_payload_data[key].is_a?(String)
          it "raises InvalidInputError if #{key} is an empty or whitespace string" do
            expect { payment.direct_charge_bank_transfer(valid_payload_data.merge(key => "")) }
              .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{key}")
            expect { payment.direct_charge_bank_transfer(valid_payload_data.merge(key => "   ")) }
              .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{key}")
          end
        end
      end

      it "raises InvalidInputError for unsupported currency" do
        invalid_payload = valid_payload_data.merge(currency: "XYZ")
        expect { payment.direct_charge_bank_transfer(invalid_payload) }
          .to raise_error(Paychangu::InvalidInputError, "XYZ currency not supported!")
      end
    end

    context "API error handling" do
      it "raises AuthenticationError for 401 status" do
        stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:direct_charge_bank],
                               request_body: expected_request_body,
                               response_body: { message: "Auth error" }, status: 401)
        expect { payment.direct_charge_bank_transfer(valid_payload_data) }
          .to raise_error(Paychangu::AuthenticationError, /Auth error.*Status: 401/)
      end

      it "raises BadRequestError for 400 status" do
        stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:direct_charge_bank],
                               request_body: expected_request_body,
                               response_body: { message: "Bad request" }, status: 400)
        expect { payment.direct_charge_bank_transfer(valid_payload_data) }
          .to raise_error(Paychangu::BadRequestError, /Bad request.*Status: 400/)
      end

       it "raises UnprocessableEntityError for 422 status" do
        stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:direct_charge_bank],
                               request_body: expected_request_body,
                               response_body: { message: "Unprocessable" }, status: 422)
        expect { payment.direct_charge_bank_transfer(valid_payload_data) }
          .to raise_error(Paychangu::UnprocessableEntityError, /Unprocessable.*Status: 422/)
      end

      it "raises APIError for other server errors (e.g., 500)" do
        stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:direct_charge_bank],
                               request_body: expected_request_body,
                               response_body: { message: "Server error" }, status: 500)
        expect { payment.direct_charge_bank_transfer(valid_payload_data) }
          .to raise_error(Paychangu::APIError, /Server error.*Status: 500/)
      end
    end
  end

  describe "#get_charge_details" do
    let(:tx_ref) { "some-tx-ref-123" }
    let(:expected_path) { "#{Paychangu::Payment::API_ENDPOINTS[:get_single_charge_details]}/#{tx_ref}" }

    it "retrieves charge details successfully" do
      stub_paychangu_request(:get, expected_path,
                             response_body: { status: "success", data: { amount: 100, currency: "MWK" } })
      response = payment.get_charge_details(tx_ref: tx_ref)
      expect(response["status"]).to eq("success")
      expect(response["data"]["amount"]).to eq(100)
    end

    context "input validations" do
      it "raises InvalidInputError if tx_ref is missing" do
        expect { payment.get_charge_details({}) }
          .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: tx_ref")
        expect { payment.get_charge_details(tx_ref: nil) }
          .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: tx_ref")
      end

      it "raises InvalidInputError if tx_ref is an empty or whitespace string" do
        expect { payment.get_charge_details(tx_ref: "") }
          .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: tx_ref")
        expect { payment.get_charge_details(tx_ref: "   ") }
          .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: tx_ref")
      end
    end

    context "API error handling" do
      it "raises NotFoundError for 404 status" do
        stub_paychangu_request(:get, expected_path,
                               response_body: { message: "Charge not found" }, status: 404)
        expect { payment.get_charge_details(tx_ref: tx_ref) }
          .to raise_error(Paychangu::NotFoundError, /Charge not found.*Status: 404/)
      end

      it "raises AuthenticationError for 401 status" do
        stub_paychangu_request(:get, expected_path,
                               response_body: { message: "Unauthorized" }, status: 401)
        expect { payment.get_charge_details(tx_ref: tx_ref) }
          .to raise_error(Paychangu::AuthenticationError, /Unauthorized.*Status: 401/)
      end

      it "raises APIError for other server errors" do
        stub_paychangu_request(:get, expected_path,
                               response_body: { message: "Server issue" }, status: 502)
        expect { payment.get_charge_details(tx_ref: tx_ref) }
          .to raise_error(Paychangu::APIError, /Server issue.*Status: 502/)
      end
    end
  end

  describe "#get_payout_mobile_operators" do
    let(:expected_path) { Paychangu::Payment::API_ENDPOINTS[:get_payout_operators] }

    it "retrieves payout mobile operators successfully" do
      stub_paychangu_request(:get, expected_path,
                             response_body: { status: "success", data: [{ name: "Operator A", code: "OP_A" }] })
      response = payment.get_payout_mobile_operators
      expect(response["status"]).to eq("success")
      expect(response["data"].first["name"]).to eq("Operator A")
    end

    context "API error handling" do
      it "raises AuthenticationError for 401 status" do
        stub_paychangu_request(:get, expected_path,
                               response_body: { message: "Unauthorized" }, status: 401)
        expect { payment.get_payout_mobile_operators }
          .to raise_error(Paychangu::AuthenticationError, /Unauthorized.*Status: 401/)
      end

      it "raises APIError for other server errors" do
        stub_paychangu_request(:get, expected_path,
                               response_body: { message: "Server error fetching operators" }, status: 500)
        expect { payment.get_payout_mobile_operators }
          .to raise_error(Paychangu::APIError, /Server error fetching operators.*Status: 500/)
      end
    end
  end

  describe "#get_payout_banks" do
    let(:expected_path) { Paychangu::Payment::API_ENDPOINTS[:get_payout_banks] }

    it "retrieves payout banks successfully" do
      stub_paychangu_request(:get, expected_path,
                             response_body: { status: "success", data: [{ name: "Bank X", code: "BNK_X" }] })
      response = payment.get_payout_banks
      expect(response["status"]).to eq("success")
      expect(response["data"].first["name"]).to eq("Bank X")
    end

    context "API error handling" do
      it "raises AuthenticationError for 401 status" do
        stub_paychangu_request(:get, expected_path,
                               response_body: { message: "Unauthorized access" }, status: 401)
        expect { payment.get_payout_banks }
          .to raise_error(Paychangu::AuthenticationError, /Unauthorized access.*Status: 401/)
      end

      it "raises APIError for other server errors" do
        stub_paychangu_request(:get, expected_path,
                               response_body: { message: "Server error fetching banks" }, status: 503)
        expect { payment.get_payout_banks }
          .to raise_error(Paychangu::APIError, /Server error fetching banks.*Status: 503/)
      end
    end
  end

  describe "#disburse_to_mobile_money" do
    let(:valid_payload_data) do
      {
        amount: 200,
        currency: "ZMW",
        phone_number: "0977123456",
        network: "MTN_ZAMBIA",
        reason: "Salary payment",
        reference: "client-ref-momo-001"
      }
    end
    let(:expected_request_body) { valid_payload_data }

    it "initiates a mobile money disbursement successfully" do
      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:disburse_momo],
                             request_body: expected_request_body,
                             response_body: { status: "success", message: "Disbursement initiated" })
      response = payment.disburse_to_mobile_money(valid_payload_data)
      expect(response["status"]).to eq("success")
      expect(response["message"]).to eq("Disbursement initiated")
    end

    context "input validations" do
      let(:required_keys) { %i[amount currency phone_number network reason reference] }

      required_keys.each do |key|
        it "raises InvalidInputError if #{key} is missing" do
          invalid_payload = valid_payload_data.dup
          invalid_payload.delete(key)
          expect { payment.disburse_to_mobile_money(invalid_payload) }
            .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{key}")
        end

        it "raises InvalidInputError if #{key} is nil" do
          expect { payment.disburse_to_mobile_money(valid_payload_data.merge(key => nil)) }
            .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{key}")
        end

        if valid_payload_data[key].is_a?(String)
          it "raises InvalidInputError if #{key} is an empty or whitespace string" do
            expect { payment.disburse_to_mobile_money(valid_payload_data.merge(key => "")) }
              .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{key}")
            expect { payment.disburse_to_mobile_money(valid_payload_data.merge(key => "   ")) }
              .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{key}")
          end
        end
      end

      it "raises InvalidInputError for unsupported currency" do
        invalid_payload = valid_payload_data.merge(currency: "EUR")
        expect { payment.disburse_to_mobile_money(invalid_payload) }
          .to raise_error(Paychangu::InvalidInputError, "EUR currency not supported!")
      end
    end

    context "API error handling" do
      it "raises BadRequestError for 400 status" do
        stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:disburse_momo],
                               request_body: expected_request_body,
                               response_body: { message: "Invalid phone number" }, status: 400)
        expect { payment.disburse_to_mobile_money(valid_payload_data) }
          .to raise_error(Paychangu::BadRequestError, /Invalid phone number.*Status: 400/)
      end

      it "raises UnprocessableEntityError for 422 status (e.g. insufficient balance)" do
        stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:disburse_momo],
                               request_body: expected_request_body,
                               response_body: { message: "Insufficient balance" }, status: 422)
        expect { payment.disburse_to_mobile_money(valid_payload_data) }
          .to raise_error(Paychangu::UnprocessableEntityError, /Insufficient balance.*Status: 422/)
      end

      it "raises APIError for other server errors (e.g., 500)" do
        stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:disburse_momo],
                               request_body: expected_request_body,
                               response_body: { message: "Disbursement service unavailable" }, status: 503)
        expect { payment.disburse_to_mobile_money(valid_payload_data) }
          .to raise_error(Paychangu::APIError, /Disbursement service unavailable.*Status: 503/)
      end
    end
  end

  describe "#disburse_to_bank_account" do
    let(:valid_payload_data) do
      {
        amount: 15000,
        currency: "NGN",
        bank_code: "044", # Example: Access Bank
        account_number: "0011223344",
        account_name: "Jane Doe",
        reason: "Vendor payment",
        reference: "client-ref-bank-002"
      }
    end
    let(:expected_request_body) { valid_payload_data }

    it "initiates a bank disbursement successfully" do
      stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:disburse_bank],
                             request_body: expected_request_body,
                             response_body: { status: "success", message: "Bank disbursement initiated" })
      response = payment.disburse_to_bank_account(valid_payload_data)
      expect(response["status"]).to eq("success")
      expect(response["message"]).to eq("Bank disbursement initiated")
    end

    context "input validations" do
      let(:required_keys) { %i[amount currency bank_code account_number account_name reason reference] }

      required_keys.each do |key|
        it "raises InvalidInputError if #{key} is missing" do
          invalid_payload = valid_payload_data.dup
          invalid_payload.delete(key)
          expect { payment.disburse_to_bank_account(invalid_payload) }
            .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{key}")
        end

        it "raises InvalidInputError if #{key} is nil" do
          expect { payment.disburse_to_bank_account(valid_payload_data.merge(key => nil)) }
            .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{key}")
        end

        if valid_payload_data[key].is_a?(String)
          it "raises InvalidInputError if #{key} is an empty or whitespace string" do
            expect { payment.disburse_to_bank_account(valid_payload_data.merge(key => "")) }
              .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{key}")
            expect { payment.disburse_to_bank_account(valid_payload_data.merge(key => "   ")) }
              .to raise_error(Paychangu::InvalidInputError, "Missing required parameter: #{key}")
          end
        end
      end

      it "raises InvalidInputError for unsupported currency" do
        invalid_payload = valid_payload_data.merge(currency: "CAD")
        expect { payment.disburse_to_bank_account(invalid_payload) }
          .to raise_error(Paychangu::InvalidInputError, "CAD currency not supported!")
      end
    end

    context "API error handling" do
      it "raises BadRequestError for 400 status (e.g. invalid bank details)" do
        stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:disburse_bank],
                               request_body: expected_request_body,
                               response_body: { message: "Invalid account number" }, status: 400)
        expect { payment.disburse_to_bank_account(valid_payload_data) }
          .to raise_error(Paychangu::BadRequestError, /Invalid account number.*Status: 400/)
      end

      it "raises UnprocessableEntityError for 422 status (e.g. name mismatch)" do
        stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:disburse_bank],
                               request_body: expected_request_body,
                               response_body: { message: "Account name mismatch" }, status: 422)
        expect { payment.disburse_to_bank_account(valid_payload_data) }
          .to raise_error(Paychangu::UnprocessableEntityError, /Account name mismatch.*Status: 422/)
      end

      it "raises APIError for other server errors" do
        stub_paychangu_request(:post, Paychangu::Payment::API_ENDPOINTS[:disburse_bank],
                               request_body: expected_request_body,
                               response_body: { message: "Payout system offline" }, status: 500)
        expect { payment.disburse_to_bank_account(valid_payload_data) }
          .to raise_error(Paychangu::APIError, /Payout system offline.*Status: 500/)
      end
    end
  end
end
