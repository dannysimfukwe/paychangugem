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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dannysimfukwe/paychangugem.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
