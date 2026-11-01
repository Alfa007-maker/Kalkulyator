import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'db.dart';

void main() => runApp(const QarzApp());

final _fmt = NumberFormat('#,###', 'en_US');
String som(int v) => "${_fmt.format(v.abs()).replaceAll(',', ' ')} so'm";

class QarzApp extends StatelessWidget {
  const QarzApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Qarz daftari',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Person> people = [];
  Map<int, int> balances = {};
  String query = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final ps = await DB.instance.persons();
    final b = <int, int>{};
    for (final p in ps) {
      b[p.id!] = await DB.instance.balanceOf(p.id!);
    }
    if (!mounted) return;
    setState(() {
      people = ps;
      balances = b;
    });
  }

  Future<void> addPerson() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Yangi odam"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Ism')),
          TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Bekor')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text("Qo'shish")),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await DB.instance.addPerson(Person(
          name: name.text.trim(),
          phone: phone.text.trim().isEmpty ? null : phone.text.trim()));
      load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final owedToMe =
        balances.values.where((v) => v > 0).fold<int>(0, (a, b) => a + b);
    final iOwe =
        balances.values.where((v) => v < 0).fold<int>(0, (a, b) => a + b);
    final shown = people
        .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Qarz daftari')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addPerson,
        icon: const Icon(Icons.person_add),
        label: const Text('Odam'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
                child: _SummaryCard(
                    title: 'Menga qarz',
                    value: som(owedToMe),
                    color: Colors.green)),
            const SizedBox(width: 8),
            Expanded(
                child: _SummaryCard(
                    title: 'Men qarzman',
                    value: som(iOwe),
                    color: Colors.red)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Qidirish',
                border: OutlineInputBorder()),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const Center(child: Text("Hozircha hech kim yo'q"))
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (c, i) {
                    final p = shown[i];
                    final b = balances[p.id] ?? 0;
                    return Dismissible(
                      key: ValueKey(p.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child:
                              const Icon(Icons.delete, color: Colors.white)),
                      confirmDismiss: (_) async =>
                          await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                    title: Text("${p.name} o'chirilsinmi?"),
                                    content: const Text(
                                        "Barcha qarzlari ham o'chadi."),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(c, false),
                                          child: const Text('Yo\'q')),
                                      FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(c, true),
                                          child: const Text("Ha")),
                                    ],
                                  )) ??
                          false,
                      onDismissed: (_) async {
                        await DB.instance.deletePerson(p.id!);
                        load();
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                            child: Text(p.name[0].toUpperCase())),
                        title: Text(p.name),
                        subtitle: p.phone != null ? Text(p.phone!) : null,
                        trailing: Text(
                          b == 0 ? "Hisob teng" : som(b),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: b > 0
                                  ? Colors.green
                                  : b < 0
                                      ? Colors.red
                                      : Colors.grey),
                        ),
                        onTap: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => PersonPage(person: p)));
                          load();
                        },
                      ),
                    );
                  }),
        ),
      ]),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title, value;
  final Color color;
  const _SummaryCard(
      {required this.title, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Card(
        color: color.withOpacity(0.12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: color)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
        ),
      );
}

class PersonPage extends StatefulWidget {
  final Person person;
  const PersonPage({super.key, required this.person});
  @override
  State<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends State<PersonPage> {
  List<Debt> debts = [];
  Map<int, int> paid = {};
  int balance = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final ds = await DB.instance.debtsOf(widget.person.id!);
    final p = <int, int>{};
    for (final d in ds) {
      p[d.id!] = await DB.instance.paidFor(d.id!);
    }
    final b = await DB.instance.balanceOf(widget.person.id!);
    if (!mounted) return;
    setState(() {
      debts = ds;
      paid = p;
      balance = b;
    });
  }

  Future<void> addDebt() async {
    final amount = TextEditingController();
    final note = TextEditingController();
    bool given = true;
    DateTime? due;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Yangi qarz'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Men berdim')),
                  ButtonSegment(value: false, label: Text('Men oldim')),
                ],
                selected: {given},
                onSelectionChanged: (s) => set(() => given = s.first),
              ),
              TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: "Summa (so'm)")),
              TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Izoh')),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(due == null
                    ? 'Qaytarish muddati'
                    : DateFormat('dd.MM.yyyy').format(due!)),
                onPressed: () async {
                  final d = await showDatePicker(
                      context: c,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100));
                  if (d != null) set(() => due = d);
                },
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Bekor')),
            FilledButton(
              onPressed: () async {
                final a = int.tryParse(amount.text) ?? 0;
                if (a <= 0) return;
                await DB.instance.addDebt(Debt(
                    personId: widget.person.id!,
                    amount: a,
                    isGiven: given,
                    date: DateTime.now(),
                    dueDate: due,
                    note: note.text.trim().isEmpty ? null : note.text.trim()));
                if (c.mounted) Navigator.pop(c);
              },
              child: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
    load();
  }

  Future<void> addPayment(Debt d) async {
    final left = d.amount - (paid[d.id] ?? 0);
    final ctrl = TextEditingController(text: left.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("To'lov qo'shish"),
        content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration:
                InputDecoration(labelText: "Summa (qolgan: ${som(left)})")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Bekor')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Saqlash')),
        ],
      ),
    );
    if (ok == true) {
      final a = int.tryParse(ctrl.text) ?? 0;
      if (a > 0 && a <= left) {
        await DB.instance.addPayment(d.id!, a);
        load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');
    return Scaffold(
      appBar: AppBar(title: Text(widget.person.name)),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: addDebt,
          icon: const Icon(Icons.add),
          label: const Text('Qarz')),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: balance >= 0
              ? Colors.green.withOpacity(0.12)
              : Colors.red.withOpacity(0.12),
          child: Text(
            balance == 0
                ? 'Hisob teng'
                : balance > 0
                    ? "U sizga qarz: ${som(balance)}"
                    : "Siz unga qarzsiz: ${som(balance)}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: debts.isEmpty
              ? const Center(child: Text("Qarz yo'q"))
              : ListView.builder(
                  itemCount: debts.length,
                  itemBuilder: (c, i) {
                    final d = debts[i];
                    final p = paid[d.id] ?? 0;
                    final left = d.amount - p;
                    final overdue = left > 0 &&
                        d.dueDate != null &&
                        d.dueDate!.isBefore(DateTime.now());
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: Icon(
                            d.isGiven
                                ? Icons.call_made
                                : Icons.call_received,
                            color: d.isGiven ? Colors.green : Colors.red),
                        title: Text(
                            "${som(d.amount)}  •  qoldi: ${som(left)}"),
                        subtitle: Text([
                          df.format(d.date),
                          if (d.dueDate != null)
                            "muddat: ${df.format(d.dueDate!)}${overdue ? ' (kechikkan!)' : ''}",
                          if (d.note != null) d.note!,
                        ].join('\n')),
                        isThreeLine: true,
                        trailing: left > 0
                            ? IconButton(
                                icon: const Icon(Icons.payments),
                                tooltip: "To'lov",
                                onPressed: () => addPayment(d))
                            : const Icon(Icons.check_circle,
                                color: Colors.green),
                        onLongPress: () async {
                          await DB.instance.deleteDebt(d.id!);
                          load();
                        },
                      ),
                    );
                  }),
        ),
      ]),
    );
  }
}
