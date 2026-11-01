import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class Person {
  final int? id;
  final String name;
  final String? phone;
  Person({this.id, required this.name, this.phone});
  Map<String, Object?> toMap() => {'id': id, 'name': name, 'phone': phone};
}

class Debt {
  final int? id;
  final int personId;
  final int amount;
  final bool isGiven; // true = men berdim (menga qarz)
  final DateTime date;
  final DateTime? dueDate;
  final String? note;
  Debt({
    this.id,
    required this.personId,
    required this.amount,
    required this.isGiven,
    required this.date,
    this.dueDate,
    this.note,
  });
  Map<String, Object?> toMap() => {
        'id': id,
        'personId': personId,
        'amount': amount,
        'isGiven': isGiven ? 1 : 0,
        'date': date.millisecondsSinceEpoch,
        'dueDate': dueDate?.millisecondsSinceEpoch,
        'note': note,
      };
  static Debt fromMap(Map<String, Object?> m) => Debt(
        id: m['id'] as int,
        personId: m['personId'] as int,
        amount: m['amount'] as int,
        isGiven: m['isGiven'] == 1,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        dueDate: m['dueDate'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['dueDate'] as int),
        note: m['note'] as String?,
      );
}

class DB {
  static final DB instance = DB._();
  DB._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'qarz.db');
    _db = await openDatabase(path, version: 1, onCreate: (d, v) async {
      await d.execute(
          'CREATE TABLE person(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT)');
      await d.execute('''CREATE TABLE debt(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        personId INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        isGiven INTEGER NOT NULL,
        date INTEGER NOT NULL,
        dueDate INTEGER,
        note TEXT)''');
      await d.execute('''CREATE TABLE payment(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debtId INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        date INTEGER NOT NULL)''');
    });
    return _db!;
  }

  Future<int> addPerson(Person p) async =>
      (await db).insert('person', p.toMap()..remove('id'));

  Future<List<Person>> persons() async {
    final r = await (await db).query('person', orderBy: 'name');
    return r
        .map((m) => Person(
            id: m['id'] as int,
            name: m['name'] as String,
            phone: m['phone'] as String?))
        .toList();
  }

  Future<void> deletePerson(int id) async {
    final d = await db;
    final debts = await d.query('debt', where: 'personId=?', whereArgs: [id]);
    for (final x in debts) {
      await d.delete('payment', where: 'debtId=?', whereArgs: [x['id']]);
    }
    await d.delete('debt', where: 'personId=?', whereArgs: [id]);
    await d.delete('person', where: 'id=?', whereArgs: [id]);
  }

  Future<int> addDebt(Debt x) async =>
      (await db).insert('debt', x.toMap()..remove('id'));

  Future<void> deleteDebt(int id) async {
    final d = await db;
    await d.delete('payment', where: 'debtId=?', whereArgs: [id]);
    await d.delete('debt', where: 'id=?', whereArgs: [id]);
  }

  Future<List<Debt>> debtsOf(int personId) async {
    final r = await (await db).query('debt',
        where: 'personId=?', whereArgs: [personId], orderBy: 'date DESC');
    return r.map(Debt.fromMap).toList();
  }

  Future<void> addPayment(int debtId, int amount) async =>
      (await db).insert('payment', {
        'debtId': debtId,
        'amount': amount,
        'date': DateTime.now().millisecondsSinceEpoch,
      });

  Future<int> paidFor(int debtId) async {
    final r = await (await db).rawQuery(
        'SELECT COALESCE(SUM(amount),0) s FROM payment WHERE debtId=?',
        [debtId]);
    return (r.first['s'] as num).toInt();
  }

  /// Odam bo'yicha qolgan balans: musbat = menga qarz, manfiy = men qarzman
  Future<int> balanceOf(int personId) async {
    int total = 0;
    for (final d in await debtsOf(personId)) {
      final left = d.amount - await paidFor(d.id!);
      total += d.isGiven ? left : -left;
    }
    return total;
  }
}
