import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/database/app_database.dart';
import 'package:pharmacy_pos/features/license/data/license_repository.dart';

void main() {
  late AppDatabase db;
  late LicenseRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = LicenseRepository(db);
  });

  tearDown(() => db.close());

  test('current is null on an unactivated device', () async {
    expect(await repo.current(), isNull);
  });

  test('activate writes the singleton row with id 1', () async {
    await repo.activate(
      activationKey: 'PH1-a-0000',
      featuresData: '{"pos":true}',
    );

    final config = await repo.current();
    expect(config, isNotNull);
    expect(config!.id, LicenseRepository.singletonId);
    expect(config.activationKey, 'PH1-a-0000');
  });

  test('re-activation replaces rather than duplicating', () async {
    await repo.activate(
      activationKey: 'PH1-old-0000',
      featuresData: '{"pos":true}',
    );
    await repo.activate(
      activationKey: 'PH1-new-0000',
      featuresData: '{"pos":false}',
    );

    final rows = await db.select(db.licenseConfig).get();
    expect(rows, hasLength(1));
    expect(rows.single.activationKey, 'PH1-new-0000');
  });

  test('updateFeatures rewrites the payload and keeps activatedAt', () async {
    await repo.activate(
      activationKey: 'PH1-a-0000',
      featuresData: '{"pos":true}',
    );
    final before = (await repo.current())!;

    // Backdate updatedAt so the refresh is observable. Without this, activate
    // and update land in the same millisecond and the assertion would pass or
    // fail on scheduling noise rather than on the behaviour under test.
    final stale = before.activatedAt.subtract(const Duration(days: 1));
    await (db.update(db.licenseConfig)
          ..where((t) => t.id.equals(LicenseRepository.singletonId)))
        .write(LicenseConfigCompanion(updatedAt: Value(stale)));

    await repo.updateFeatures(featuresData: '{"pos":true,"credit":true}');
    final after = (await repo.current())!;

    expect(after.featuresData, contains('credit'));
    expect(after.activatedAt, before.activatedAt);
    expect(after.updatedAt.isAfter(stale), isTrue);
  });

  test('updateFeatures before activation throws', () async {
    expect(
      () => repo.updateFeatures(featuresData: '{}'),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'a hand-written second row is rejected by the CHECK constraint',
    () async {
      await repo.activate(activationKey: 'PH1-a-0000', featuresData: '{}');
      expect(
        () => db
            .into(db.licenseConfig)
            .insert(
              LicenseConfigCompanion.insert(
                id: const Value(2),
                activationKey: 'PH1-forged-0000',
                featuresData: '{}',
                activatedAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 1),
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
      expect(await db.select(db.licenseConfig).get(), hasLength(1));
    },
  );
}
