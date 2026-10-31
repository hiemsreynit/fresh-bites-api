# fresh_bites_api

[![style: dart frog lint][dart_frog_lint_badge]][dart_frog_lint_link]
[![License: MIT][license_badge]][license_link]
[![Powered by Dart Frog](https://img.shields.io/endpoint?url=https://tinyurl.com/dartfrog-badge)](https://dart-frog.dev)

Fresh Bites API built with Dart Frog and MongoDB.

## Authentication setup

The API creates the `auth_tokens` collection and its token-hash and expiration
indexes on startup. Public registration creates `customer` accounts only. To
provision the first administrator, register an account and promote it through a
trusted MongoDB administrative session:

```javascript
db.users.updateOne(
  { email: "admin@example.com" },
  { $set: { role: "admin", updatedAt: new Date() } }
)
```

Never expose database credentials or administrator provisioning through the
public API. Access tokens are opaque bearer tokens, stored as SHA-256 hashes,
and expire after seven days.

[dart_frog_lint_badge]: https://img.shields.io/badge/style-dart_frog_lint-1DF9D2.svg
[dart_frog_lint_link]: https://pub.dev/packages/dart_frog_lint
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT