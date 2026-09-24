import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pointycastle/export.dart';

import '../../../core/database/app_database.dart';

/// A completed backup, ready to hand to the OS share sheet or a cloud adapter.
class BackupArtifact {
  const BackupArtifact({
    required this.suggestedFileName,
    required this.bytes,
    required this.databaseBytes,
    required this.createdAt,
  });

  /// Timestamped, e.g. `pharmacy-backup-20260924-143000.pbak`.
  final String suggestedFileName;

  /// The encrypted, versioned envelope — this is the only thing that leaves the
  /// device. The plaintext database size is deliberately *not* leaked into the
  /// file name; only the creation instant is.
  final Uint8List bytes;

  /// The (already collected) raw SQLite snapshot, kept so the local file-export
  /// adapter can optionally save the unencrypted db too for debugging. `null`
  /// handling is left to the caller.
  final Uint8List databaseBytes;

  final DateTime createdAt;
}

/// Where a backup's plaintext came from, for restore-time validation.
///
/// Not stored in the envelope as a Dart type — the JSON inside the ZIP is the
/// wire form — but the service hands it back after [BackupService.readManifest]
/// so a caller can show the user "this file is from 2026-09-20, schema 4" before
/// they confirm a destructive restore.
class BackupManifest {
  const BackupManifest({required this.createdAt, required this.schemaVersion});

  final DateTime createdAt;
  final int schemaVersion;
}

/// Secure, self-describing database backup and restore (Module 7).
///
/// The envelope is the whole design surface, so it is versioned and
/// self-describing rather than trusting the file name:
///
/// ```text
/// "PPBK"            magic   (4 bytes) — reject a non-backup file early
/// version           (1 byte)  = 1
/// KDF salt          (16 bytes) random per backup
/// KDF iterations    (4 bytes, big-endian)
/// GCM nonce         (12 bytes) random per backup
/// ciphertext        (rest) AES-256-GCM of the ZIP, tag appended by the cipher
/// ```
///
/// The passphrase is stretched with PBKDF2-HMAC-SHA256 before it becomes an AES
/// key: a short human PIN has ~4–8 bytes of entropy, and feeding it raw would let
/// anyone holding the file brute-force it in seconds. The per-backup salt means
/// two backups of the same database with the same passphrase are byte-different,
/// and a precomputed rainbow table is useless.
///
/// AES-GCM (not CBC) is chosen because it authenticates: a tampered or truncated
/// file, or a wrong passphrase, fails the tag check on restore instead of
/// decrypting to garbage that SQLite then half-opens. A corrupt live database is
/// far worse than an obvious failed restore.
///
/// The plaintext side is a ZIP holding one file — the database — collected via
/// `VACUUM INTO`, which writes a fresh, WAL-free, transactionally consistent copy
/// while the app keeps running. Copying the `.db` file directly would miss the
/// `-wal` sidecar (uncommitted-at-snapshot rows) and could capture a torn page
/// under concurrent writes. `archive` is used rather than hand-rolling a
/// container so a backup is a normal `.zip` once decrypted, and the manifest
/// travels inside it.
class BackupService {
  BackupService(this._db, {int? iterations})
    : _iterations = iterations ?? kDefaultIterations;

  /// The live database to snapshot and, on restore, to replace.
  final AppDatabase _db;

  /// PBKDF2 rounds. Lower in tests (via the constructor) to keep the suite fast;
  /// production default is deliberately high — a backup file may sit in someone's
  /// cloud drive for years, so offline brute-force must stay expensive.
  final int _iterations;

  static const int kDefaultIterations = 150000;
  static const int _testIterationsHint = 1000;

  /// Suggested iterations for a CI/test round trip. Exposed so the test file
  /// does not hard-code a magic number that could drift from the production
  /// default's relationship to it.
  static int get kTestIterations => _testIterationsHint;

  static const List<int> _magic = <int>[0x50, 0x50, 0x42, 0x4B]; // "PPBK"
  static const int _version = 1;
  static const int _saltBytes = 16;
  static const int _nonceBytes = 12;
  static const int _keyBytes = 32; // AES-256
  static const int _macBytes = 16; // GCM tag

  final Random _rng = Random.secure();

  // ------------------------------------------------------------- export

  /// Produce an encrypted backup envelope for the current database state.
  ///
  /// [passphrase] is required and non-blank: an unencrypted backup of patient
  /// purchase history is exactly the thing that gets emailed around a pharmacy
  /// chain, so there is deliberately no "no password" mode.
  Future<BackupArtifact> createBackup(String passphrase) async {
    final password = _requirePassphrase(passphrase);
    final snapshot = await snapshotDatabase();

    final archive = Archive();
    archive.addFile(ArchiveFile(_dbEntryName, snapshot.length, snapshot));
    final manifest = utf8.encode(
      jsonEncode({
        'format': _magicStr,
        'version': _version,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'schema_version': kSchemaVersion,
      }),
    );
    archive.addFile(ArchiveFile(_manifestEntryName, manifest.length, manifest));
    final zip = Uint8List.fromList(ZipEncoder().encode(archive));

    final salt = _randomBytes(_saltBytes);
    final nonce = _randomBytes(_nonceBytes);
    final key = _deriveKey(password, salt);
    final ciphertext = _gcm(
      key: key,
      nonce: nonce,
      plaintext: zip,
      forEncryption: true,
    );

    final envelope = BytesBuilder()
      ..add(_magic)
      ..addByte(_version)
      ..add(salt)
      ..add(_be32(_iterations))
      ..add(nonce)
      ..add(ciphertext);

    final bytes = envelope.toBytes();
    final name = _fileNameFor(DateTime.now());
    return BackupArtifact(
      suggestedFileName: name,
      bytes: bytes,
      databaseBytes: snapshot,
      createdAt: DateTime.now(),
    );
  }

  /// A single, consistent, WAL-free copy of the database as raw SQLite bytes.
  ///
  /// Uses `VACUUM INTO` (not a file copy) for the reasons on the class doc:
  /// it is atomic, excludes the `-wal` sidecar, and never sees a torn page. The
  /// snapshot is written to a temp file in the *same* directory the caller can
  /// reach, read back, then deleted.
  Future<Uint8List> snapshotDatabase() async {
    final tmp = File(
      '${Directory.systemTemp.path}/ppbk_snap_${_rng.nextInt(1 << 32).toRadixString(16)}.db',
    );
    // The path is fully generated above (temp dir + our own hex name), never
    // derived from user input, so embedding it in the statement is safe;
    // VACUUM INTO does not accept a bound parameter for the target name.
    final escaped = tmp.path.replaceAll("'", "''");
    try {
      await _db.customStatement("VACUUM INTO '$escaped'");
      return await tmp.readAsBytes();
    } finally {
      if (tmp.existsSync()) {
        try {
          await tmp.delete();
        } on FileSystemException {
          // Best-effort cleanup of a temp file; the OS reclaims it otherwise.
        }
      }
    }
  }

  // ------------------------------------------------------------- restore

  /// Decrypt [envelope] and report what is inside it, without touching any
  /// live database.
  ///
  /// The restore screen calls this first: confirming "replace everything with
  /// this file" needs the file's creation date and schema version on screen, and
  /// a wrong passphrase must be discovered *here* rather than halfway through a
  /// file swap.
  Future<BackupManifest> inspect(Uint8List envelope, String passphrase) async {
    final zip = _openEnvelope(envelope, passphrase);
    final archive = ZipDecoder().decodeBytes(zip);
    final entry = archive.find(_manifestEntryName);
    if (entry == null) {
      throw const BackupFormatException('Backup carries no manifest.');
    }
    final decoded = jsonDecode(
      utf8.decode(entry.content as List<int>),
    ) as Map<String, Object?>;
    return BackupManifest(
      createdAt: DateTime.parse(decoded['created_at']! as String).toLocal(),
      schemaVersion: decoded['schema_version']! as int,
    );
  }

  /// Decrypt and unzip [envelope], returning the raw database bytes.
  ///
  /// Throws [BackupFormatException] on a bad magic/version/structure and
  /// [BackupAuthException] when the passphrase is wrong or the bytes were
  /// tampered with (both surface as a GCM tag failure, so they are the same
  /// signal here — an attacker cannot tell a wrong password from a corrupted
  /// file, which is the desired property).
  Future<Uint8List> decryptDatabaseBytes(
    Uint8List envelope,
    String passphrase,
  ) async {
    final zip = _openEnvelope(envelope, passphrase);
    final archive = ZipDecoder().decodeBytes(zip);
    final dbFile = archive.find(_dbEntryName);
    if (dbFile == null) {
      throw const BackupFormatException('Backup is missing the database file.');
    }
    return Uint8List.fromList(dbFile.content as List<int>);
  }

  /// Parse + authenticate the envelope, returning the decrypted ZIP bytes.
  ///
  /// Shared by [inspect] and [decryptDatabaseBytes] so the wire format is
  /// parsed and authenticated in precisely one place.
  Uint8List _openEnvelope(Uint8List data, String passphrase) {
    final password = _requirePassphrase(passphrase);
    if (data.length <
        _magic.length + 1 + _saltBytes + 4 + _nonceBytes + _macBytes) {
      throw const BackupFormatException('Backup file is truncated.');
    }
    var pos = 0;
    for (final b in _magic) {
      if (data[pos++] != b) {
        throw const BackupFormatException('Not a pharmacy backup file.');
      }
    }
    final version = data[pos++];
    if (version != _version) {
      throw BackupFormatException('Unsupported backup version $version.');
    }
    final salt = data.sublist(pos, pos + _saltBytes);
    pos += _saltBytes;
    final iterations = _readBe32(data, pos);
    pos += 4;
    final nonce = data.sublist(pos, pos + _nonceBytes);
    pos += _nonceBytes;
    final ciphertext = data.sublist(pos);

    final key = _deriveKey(password, salt, iterations: iterations);
    final Uint8List zip;
    try {
      zip = _gcm(
        key: key,
        nonce: nonce,
        plaintext: ciphertext,
        forEncryption: false,
      );
    } on InvalidCipherTextException {
      throw const BackupAuthException(
        'Wrong passphrase, or the backup was modified.',
      );
    }
    return zip;
  }

  /// Replace the live database file with [dbBytes], as safely as the app can
  /// arrange it, then hand back a freshly-opened [AppDatabase] on the new file.
  ///
  /// [reopen] builds the new handle after the old one is closed; the caller
  /// supplies it because opening the database is the app's job (drift_flutter,
  /// provider override), not this service's. Keeping it a callback is what lets
  /// the restore test drive the real file swap while production wires it to the
  /// Riverpod provider.
  ///
  /// Order matters: write to a sibling temp file and fsync it *before* closing
  /// the live connection, so a crash mid-restore leaves the old database intact
  /// rather than half-overwritten. Only once the new bytes are fully on disk is
  /// the current file replaced and the connection reopened.
  Future<AppDatabase> restoreIntoPlace({
    required Uint8List dbBytes,
    required File liveFile,
    required AppDatabase Function() reopen,
  }) async {
    final staging = File('${liveFile.path}.restore.tmp');
    await staging.writeAsBytes(dbBytes, flush: true);

    // Close the current handle so no connection holds the file during the swap,
    // and so SQLite's WAL/-shm sidecars are released cleanly.
    await _db.close();
    try {
      await staging.rename(liveFile.path);
    } on FileSystemException {
      // rename across a filesystem boundary can fail; fall back to copy+delete.
      await staging.copy(liveFile.path);
      await staging.delete();
    }
    for (final suffix in const ['-wal', '-shm']) {
      final sidecar = File('${liveFile.path}$suffix');
      if (sidecar.existsSync()) {
        try {
          await sidecar.delete();
        } on FileSystemException {
          // A leftover -wal from the pre-restore connection is stale; SQLite
          // ignores it against a new main file it did not write.
        }
      }
    }
    return reopen();
  }

  // ------------------------------------------------------------- crypto

  Uint8List _deriveKey(String password, Uint8List salt, {int? iterations}) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations ?? _iterations, _keyBytes));
    return derivator.process(utf8.encode(password));
  }

  Uint8List _gcm({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List plaintext,
    required bool forEncryption,
  }) {
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(key),
      _macBytes * 8,
      nonce,
      Uint8List(0), // empty AAD; the file name carries no secret to bind
    );
    cipher.init(forEncryption, params);
    return cipher.process(plaintext);
  }

  // ------------------------------------------------------------- helpers

  static const String _dbEntryName = 'pharmacy_pos.db';
  static const String _manifestEntryName = 'manifest.json';
  static const String _magicStr = 'PPBK';

  String _requirePassphrase(String value) {
    if (value.trim().isEmpty) {
      throw const BackupRejectException(
        'A backup passphrase is required; unencrypted exports are not offered.',
      );
    }
    return value;
  }

  String _fileNameFor(DateTime when) {
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${when.year}${two(when.month)}${two(when.day)}'
        '-${two(when.hour)}${two(when.minute)}${two(when.second)}';
    return 'pharmacy-backup-$stamp.pbak';
  }

  Uint8List _randomBytes(int count) {
    final out = Uint8List(count);
    for (var i = 0; i < count; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }

  static List<int> _be32(int value) => [
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];

  static int _readBe32(Uint8List data, int offset) =>
      (data[offset] << 24) |
      (data[offset + 1] << 16) |
      (data[offset + 2] << 8) |
      data[offset + 3];
}

class BackupRejectException implements Exception {
  const BackupRejectException(this.message);
  final String message;
  @override
  String toString() => 'BackupRejectException: $message';
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => 'BackupFormatException: $message';
}

class BackupAuthException implements Exception {
  const BackupAuthException(this.message);
  final String message;
  @override
  String toString() => 'BackupAuthException: $message';
}
