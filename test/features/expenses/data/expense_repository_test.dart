import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/database/app_database.dart';
import 'package:pharmacy_pos/features/expenses/data/expense_repository.dart';

/// `expenses` is the only input the profit report reads that is neither a sale
/// nor a purchase; these tests pin the arithmetic on the read side
/// ([ExpenseRepository.totalInPeriod] and the per-category breakdown) so the
/// Net Profit line has an honest denominator.
void main() {
  late AppDatabase db;
  late ExpenseRepository expenses;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    expenses = ExpenseRepository(db);
  });

  tearDown(() => db.close());

  DateTime at(int daysAgo, {int hour = 12}) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - daysAgo, hour);
  }

  group('create', () {
    test('stores a positive expense and reads back a matching row', () async {
      final created = await expenses.create(
        category: 'Electricity',
        amountPya: 25000,
        note: 'October bill',
        enteredByUserId: null,
        at: at(0),
      );
      expect(created.id, greaterThan(0));
      expect(created.category, 'Electricity');
      expect(created.amount, 25000);
      expect(created.note, 'October bill');
    });

    test('a blank category is refused', () {
      expect(
        () => expenses.create(category: '   ', amountPya: 1000),
        throwsA(isA<ExpenseRejectException>()),
      );
    });

    test('a zero or negative amount is refused', () {
      for (final bad in [0, -500]) {
        expect(
          () => expenses.create(category: 'Rent', amountPya: bad),
          throwsA(isA<ExpenseRejectException>()),
        );
      }
    });

    test('a blank note is stored as null', () async {
      final e = await expenses.create(
        category: 'Water',
        amountPya: 1000,
        note: '  ',
      );
      expect(e.note, isNull);
    });
  });

  group('list', () {
    test('newest first, with a period window and a category filter', () async {
      await expenses.create(category: 'Rent', amountPya: 100000, at: at(3));
      await expenses.create(
        category: 'Electricity',
        amountPya: 25000,
        at: at(1),
      );
      await expenses.create(category: 'Salary', amountPya: 200000, at: at(0));

      final all = await expenses.list();
      expect(all.map((e) => e.category), ['Salary', 'Electricity', 'Rent']);

      final today = await expenses.list(from: at(0), to: at(-1));
      expect(today.map((e) => e.category), ['Salary']);

      final onlyRent = await expenses.list(category: 'Rent');
      expect(onlyRent.map((e) => e.category), ['Rent']);
    });

    test('search matches category and note text', () async {
      await expenses.create(category: 'Bus fare', amountPya: 100);
      await expenses.create(
        category: 'Marketing',
        amountPya: 500,
        note: 'facebook ad',
      );
      expect((await expenses.list(search: 'face')).map((e) => e.category), [
        'Marketing',
      ]);
      expect((await expenses.list(search: 'fare')).map((e) => e.category), [
        'Bus fare',
      ]);
    });
  });

  group('totalInPeriod', () {
    test('sums only the window and treats it as [from, to)', () async {
      // Two entries on either side of today's midnight, one on top of it.
      await expenses.create(category: 'Yesterday', amountPya: 1000, at: at(1));
      await expenses.create(category: 'Today', amountPya: 2000, at: at(0));
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final start = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
      // Insert one at a fixed future timestamp so we can prove [to) is exclusive.
      await expenses.create(
        category: 'Tomorrow',
        amountPya: 4000,
        at: start.add(const Duration(hours: 6)),
      );

      final window = await expenses.totalInPeriod(from: at(0), to: start);
      expect(window, 2000);
    });

    test('an empty period returns 0, not null', () async {
      final empty = await expenses.totalInPeriod(
        from: DateTime.utc(1999),
        to: DateTime.utc(2000),
      );
      expect(empty, 0);
    });
  });

  group('totalsByCategory', () {
    test('groups, sums, and orders largest-first', () async {
      await expenses.create(category: 'Rent', amountPya: 100000, at: at(3));
      await expenses.create(category: 'Rent', amountPya: 100000, at: at(1));
      await expenses.create(category: 'Water', amountPya: 5000, at: at(0));
      final totals = await expenses.totalsByCategory();
      expect(totals.map((t) => t.category), ['Rent', 'Water']);
      expect(totals.first.totalPya, 200000);
      expect(totals.first.entryCount, 2);
    });
  });

  group('delete', () {
    test('removes the row by id', () async {
      final created = await expenses.create(category: 'Bus', amountPya: 500);
      await expenses.delete(created.id);
      expect(await expenses.byId(created.id), isNull);
    });
  });
}
