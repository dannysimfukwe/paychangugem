# Paychangu Rails Gem

## Installation

Install the gem and add to the application's Gemfile by executing:

```ruby
$ bundle add paychangu
```

If bundler is not being used to manage dependencies, install the gem by executing:

```ruby    
$ gem install paychangu
```

## Usage

Create an initializer in your application's `config > initializers` folder, for example `paychangu.rb` and paste the following

```ruby
require "paychangu"
```

Then use it in your application like below with your Paychangu secret key, you can get this key in your Paychangu account settings

```ruby
paychangu = Paychangu::Payment.new("sec-test-SDsYTCSh...")
```

#### Creating a Payment Link

```ruby
 payload = {
        amount: "50000",
        currency: "MWK",
        email: "test@example.com",
        first_name: "Danny",
        last_name: "Simfukwe",
        callback_url: "https://webhook.site/9d0b00ba-9a69-44fa-a43d-a82c33c36fdc",
        return_url: "https://webhook.site",
        tx_ref: SecureRandom.hex(10),
        title: "Title of payment",
        description: "Description of payment",
        logo: "https://assets.piedpiper.com/logo.png"
    }
```

 ```ruby
link = paychangu.create_payment_link(payload)
```

 #### Creating a Virtual Card

```ruby
card_payload = {
        amount: "500",
        currency: "USD",
        first_name: "Danny",
        last_name: "Simfukwe",
        callback_url: "https://webhook.site/9d0b00ba-9a69-44fa-a43d-a82c33c36fdc"
    }
```

```ruby 
card = paychangu.create_virtual_card(card_payload)
```

 #### Funding a Virtual Card

```rbuy
 fund_card_payload = {
      amount: "50000",
      card_hash: card[:card_hash],
    }
```

 ```ruby 
paychangu.fund_card(fund_card_payload)
```

 #### Withdrawing from a Virtual Card

  ```ruby 
withdraw = paychangu.withdraw_card_funds(fund_card_payload)
```

  #### Buying Airtime

  First get all operators

  ```ruby
   operators = paychangu.airtime_operators

  ```

  Then use the operator's ID to buy Airtime

  ```ruby
    airtime_payment_payload = {
        operator: "123",
        amount: "300",
        phone: "0900000000",
        callback_url: "https://webhook.site/9d0b00ba-9a69-44fa-a43d-a82c33c36fdc"
    }

    paychangu.airtime_payment(airtime_payment_payload)
  ```

#### Verifying a Payment/Charge

To verify any transaction or get its details (Payment Links, Direct Charges):

```ruby
# tx_ref is the transaction reference you provided or was auto-generated
charge_details_payload = {
  tx_ref: "your_transaction_reference"
}

details = paychangu.verify_payment(charge_details_payload) # For payment links (existing)
# OR for any charge:
details = paychangu.get_charge_details(charge_details_payload)
# Note: verify_payment might be specific to payment links,
# while get_charge_details is more generic if their API differentiates.
# Assuming get_charge_details is the new generic one for charge status.
```
Response will contain the status and details of the transaction.

### Direct Charges

These methods allow you to directly charge a customer's mobile money or bank account. Ensure you have proper authorization from your customers before using these methods.

#### Direct Mobile Money Charge

```ruby
direct_momo_payload = {
  amount: "2500", # Amount to charge
  currency: "MWK", # Supported currency e.g MWK, NGN, ZMW, USD, GBP, ZAR
  email: "customer@example.com", # Customer's email
  phone_number: "0999000000", # Customer's phone number
  network: "AIRTEL", # Mobile money network (e.g., AIRTEL, TNM, MTN_ZAMBIA)
  first_name: "John",
  last_name: "Doe",
  callback_url: "https://yourdomain.com/callback", # URL for transaction status updates
  return_url: "https://yourdomain.com/return", # URL to redirect customer after attempt
  tx_ref: SecureRandom.hex(10) # Optional: Your unique transaction reference
}

response = paychangu.direct_charge_mobile_money(direct_momo_payload)
# Check response for success or failure
```

#### Direct Bank Transfer Charge

```ruby
direct_bank_payload = {
  amount: "15000", # Amount to charge
  currency: "NGN", # Supported currency
  email: "customer@example.com",
  bank_code: "058", # Code for the customer's bank
  account_number: "0123456789", # Customer's bank account number
  first_name: "Jane",
  last_name: "Doe",
  callback_url: "https://yourdomain.com/callback",
  return_url: "https://yourdomain.com/return",
  tx_ref: SecureRandom.hex(10) # Optional
}

response = paychangu.direct_charge_bank_transfer(direct_bank_payload)
# Check response
```

### Disbursements (Payouts)

These methods allow you to send funds to mobile money accounts or bank accounts.

#### Get Payout Mobile Operators

Before disbursing to mobile money, you might need a list of supported operators.

```ruby
operators_list = paychangu.get_payout_mobile_operators()
# This will return a list of available mobile money operators for payouts
```

#### Get Payout Banks

Similarly, for bank disbursements, get a list of supported banks.

```ruby
banks_list = paychangu.get_payout_banks()
# This will return a list of available banks for payouts
```

#### Disburse to Mobile Money

```ruby
disburse_momo_payload = {
  amount: "2000", # Amount to send
  currency: "ZMW", # Supported currency
  phone_number: "0977123456", # Recipient's phone number
  network: "MTN_ZAMBIA", # Recipient's mobile money network code from get_payout_mobile_operators
  reason: "Refund for order TX123", # Reason for the disbursement
  reference: SecureRandom.hex(12) # Your unique reference for this payout
}

response = paychangu.disburse_to_mobile_money(disburse_momo_payload)
# Check response
```

#### Disburse to Bank Account

```ruby
disburse_bank_payload = {
  amount: "50000", # Amount to send
  currency: "NGN",
  bank_code: "044", # Recipient's bank code from get_payout_banks
  account_number: "0011223344", # Recipient's account number
  account_name: "Recipient Name", # Recipient's account name
  reason: "Payment for services rendered",
  reference: SecureRandom.hex(12) # Your unique reference for this payout
}

response = paychangu.disburse_to_bank_account(disburse_bank_payload)
# Check response
```

## Controbuting

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dannysimfukwe/paychangugem.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
