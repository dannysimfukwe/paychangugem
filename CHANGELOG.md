## [Unreleased] - YYYY-MM-DD

### Added
- Custom error classes for improved error handling (`Paychangu::AuthenticationError`, `Paychangu::InvalidInputError`, `Paychangu::APIError`).
- Comprehensive unit tests with `webmock` for all public API methods, ensuring better reliability and easier refactoring.

### Changed
- **Breaking Change:** Switched HTTP client from `Net::HTTP` to `httparty`. While method signatures for public API calls remain the same, underlying HTTP behavior and error handling details have changed. Callers relying on specific `Net::HTTP` exceptions or behaviors might need to adapt.
- **Breaking Change:** Standard `RuntimeError` exceptions (e.g., for invalid input or API errors) are replaced by more specific custom errors:
    - `Paychangu::InvalidInputError` for issues like missing secret keys or unsupported currencies.
    - `Paychangu::AuthenticationError` for 401 API errors.
    - `Paychangu::InvalidInputError` for 400, 404, 422 API errors.
    - `Paychangu::APIError` for other API-related errors (e.g., 5xx status codes, connection issues).
- Refactored internal request processing logic for clarity, leveraging `httparty` for request execution and `handle_response` for centralized error management.
- Payload generation methods (e.g., `create_link_payload`) now return Ruby Hashes internally, with JSON conversion handled by the HTTP client layer.

### Fixed
- Ensured consistent error handling and reporting across different API interaction scenarios.
- Improved test coverage significantly.

## [0.1.0] - 2023-12-12

- Initial release
