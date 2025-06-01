## [0.2.0] - YYYY-MM-DD (Replace YYYY-MM-DD with today's date upon release)

### Added
- **Direct Charge Methods:**
    - `direct_charge_mobile_money(data)`: Initiate direct payments from mobile money accounts.
    - `direct_charge_bank_transfer(data)`: Initiate direct payments from bank accounts.
- **Disbursement (Payout) Methods:**
    - `disburse_to_mobile_money(data)`: Send funds to mobile money accounts.
    - `disburse_to_bank_account(data)`: Send funds to bank accounts.
    - `get_payout_mobile_operators()`: Retrieve a list of mobile money operators for payouts.
    - `get_payout_banks()`: Retrieve a list of banks eligible for payouts.
- **Transaction Querying:**
    - `get_charge_details(data)`: Get details for a specific charge transaction using `tx_ref`.
- Custom error classes for improved error handling (e.g., `Paychangu::AuthenticationError`, `Paychangu::BadRequestError`, `Paychangu::NotFoundError`, `Paychangu::UnprocessableEntityError`, `Paychangu::InvalidInputError`, `Paychangu::APIError`). (Consolidating from previous unreleased notes)
- Comprehensive unit tests with `webmock` for all public API methods. (Consolidating from previous unreleased notes)
- Added `.ruby-version` file specifying Ruby 3.3.0.

### Changed
- **Breaking Change:** Switched HTTP client from `Net::HTTP` to `httparty`. While method signatures for public API calls remain the same, underlying HTTP behavior and error handling details have changed. Callers relying on specific `Net::HTTP` exceptions or behaviors might need to adapt. (Consolidating from previous unreleased notes)
- **Breaking Change:** Standard `RuntimeError` exceptions are replaced by more specific custom errors (see Added section for error classes). (Consolidating from previous unreleased notes)
- Updated required Ruby version to `~> 3.3.0` in `paychangu.gemspec` and `Gemfile`.
- Updated CI workflow (`.github/workflows/main.yml`) to use Ruby 3.3.0.
- Refactored internal request processing logic for clarity, leveraging `httparty`. (Consolidating from previous unreleased notes)
- Payload generation methods now return Ruby Hashes internally, with JSON conversion handled by the HTTP client layer. (Consolidating from previous unreleased notes)

### Fixed
- Ensured consistent error handling and reporting across different API interaction scenarios. (Consolidating from previous unreleased notes)
- Improved test coverage significantly. (Consolidating from previous unreleased notes)
- Removed unnecessary code comments in `lib/paychangu.rb` for improved clarity.

## [0.1.0] - 2023-12-12

- Initial release
