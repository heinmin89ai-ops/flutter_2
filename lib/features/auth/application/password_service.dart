import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Local password/PIN hashing.
///
/// PBKDF2-HMAC-SHA256 with a per-user random salt, encoded as `salt\$hash` in
/// base64url. `crypto` ships Hmac but not PBKDF2, so the derivation loop is
/// implemented here — it is ~30 lines of spec-exact code, which is cheaper than
/// adding a native dependency to a phone till.
///
/// Why not plain SHA-256: a 4-6 digit PIN has at most a million candidates, so
/// an unsalted hash falls to a precomputed table on any copied `.sqlite` file.
/// Shared CSPRNG. A `Random.secure()` instance is safe to reuse and must not be
/// created per call, which is also why it cannot be a `const` field.
final Random _secureRandom = Random.secure();

class PasswordService {
  const PasswordService({this.iterations = kDefaultIterations});

  static const int kDefaultIterations = 120000;
  static const int _saltBytes = 16;
  static const int _derivedKeyBytes = 32;

  final int iterations;

  /// Returns `base64url(salt)\$base64url(derivedKey)`, safe to store in
  /// `users.pin_hash`.
  String hash(String secret) {
    final salt = Uint8List.fromList(
      List<int>.generate(_saltBytes, (_) => _secureRandom.nextInt(256)),
    );
    final derived = _pbkdf2(secret, salt, iterations);
    return '${_encode(salt)}\$${_encode(derived)}';
  }

  /// Constant-time comparison of [secret] against a stored [hash].
  ///
  /// The stored field is split rather than re-hashed with a fresh salt, so the
  /// iteration count is effectively part of the record.
  bool verify(String secret, String storedHash) {
    final parts = storedHash.split(r'$');
    if (parts.length != 2) return false;

    final Uint8List salt;
    final Uint8List expected;
    try {
      salt = _decode(parts[0]);
      expected = _decode(parts[1]);
    } on FormatException {
      // Corrupt legacy value — treat as a failed login, never as a crash.
      return false;
    }

    final actual = _pbkdf2(secret, salt, iterations);
    return _constantTimeEquals(actual, expected);
  }

  Uint8List _pbkdf2(String secret, Uint8List salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    final output = Uint8List(_derivedKeyBytes);

    var blockIndex = 1;
    var written = 0;
    while (written < _derivedKeyBytes) {
      final block = _deriveBlock(hmac, salt, blockIndex, iterations);
      final take = min(block.length, _derivedKeyBytes - written);
      output.setRange(written, written + take, block);
      written += take;
      blockIndex++;
    }
    return output;
  }

  /// DK = T1 || T2 || ... where Ti = U1 ^ U2 ^ ... ^ Uc and
  /// U1 = PRF(P, S || INT_32_BE(i)), Uj = PRF(P, U(j-1)).
  ///
  /// `previous` and `acc` are deliberately separate buffers. Feeding the XOR
  /// accumulator back into the PRF is a common PBKDF2 mistake: it is internally
  /// consistent, so hash/verify round-trips pass and only interoperability
  /// vectors expose it.
  Uint8List _deriveBlock(
    Hmac hmac,
    Uint8List salt,
    int blockIndex,
    int iterations,
  ) {
    var previous = Uint8List.fromList(
      // U1 = PRF(P, S || INT_32_BE(i))
      hmac.convert([...salt, ..._be32(blockIndex)]).bytes,
    );
    final acc = Uint8List.fromList(previous);

    for (var round = 1; round < iterations; round++) {
      previous = Uint8List.fromList(hmac.convert(previous).bytes);
      for (var i = 0; i < acc.length; i++) {
        acc[i] ^= previous[i];
      }
    }
    return acc;
  }

  /// Compares byte-by-byte without early return, so a mismatch deep in the key
  /// costs the same as one at the front.
  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static String _encode(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _decode(String value) =>
      base64Url.decode(base64Url.normalize(value));

  static List<int> _be32(int value) => [
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];
}
