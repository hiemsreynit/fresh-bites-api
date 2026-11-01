# fresh_bites_api

[![style: dart frog lint][dart_frog_lint_badge]][dart_frog_lint_link]
[![License: MIT][license_badge]][license_link]
[![Powered by Dart Frog](https://img.shields.io/endpoint?url=https://tinyurl.com/dartfrog-badge)](https://dart-frog.dev)

Fresh Bites API built with Dart Frog and MongoDB.

## Authentication setup

The API creates the authentication collections and their indexes on startup.
Public registration creates unverified `customer` accounts only, then emails a
single-use six-digit OTP that expires after 10 minutes. Verification is limited
to five attempts and OTP resends have a one-minute cooldown. Login is disabled
until the email address is verified.

If email delivery fails after registration, the unverified customer remains in
the database. Correct the SMTP settings and call `POST /auth/resend-otp` with
the same email address; registration can also be retried to trigger a resend.

Configure `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, and
`SMTP_FROM_EMAIL` in `.env` with your provider's SMTP settings. `SMTP_HOST`
must contain only a hostname or IP address (for example, `smtp.gmail.com`); put
the port in `SMTP_PORT`. Set
`OTP_HASH_SECRET` to a randomly generated secret of at least 32 characters
(generate at least 32 random bytes with a cryptographically secure secret
generator). Keep the value stable across application restarts.
The OTP is stored only as an HMAC digest keyed by this secret. Do not use
production credentials in `.env.example`.

To provision the first administrator, register and verify an account, then
promote it through a trusted MongoDB administrative session:

```javascript
db.users.updateOne(
  { email: "admin@example.com" },
  { $set: { role: "admin", emailVerified: true, updatedAt: new Date() } }
)
```

Never expose database credentials or administrator provisioning through the
public API. Access tokens are opaque bearer tokens, stored as SHA-256 hashes,
and expire after seven days. Existing administrator records must be marked
`emailVerified: true` through the trusted database session before login.

[dart_frog_lint_badge]: https://img.shields.io/badge/style-dart_frog_lint-1DF9D2.svg
[dart_frog_lint_link]: https://pub.dev/packages/dart_frog_lint
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT