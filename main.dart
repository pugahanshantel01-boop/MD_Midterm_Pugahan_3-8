// ===========================================================================
// Community Learning Center Management System
// DartPad version: paste into https://dartpad.dev and press Run.
// DartPad has no keyboard (stdin), so user input is read from the
// scripted list `scriptedInputs` below, and every answer is echoed to
// the console just like a typed answer.
// ===========================================================================

// ------------------------------ Exceptions ---------------------------------

/// Thrown whenever a business rule or validation rule is violated.
class CenterException implements Exception {
  final String message;
  CenterException(this.message);

  @override
  String toString() => message;
}

// -------------------------------- Mixin ------------------------------------

/// Reusable behavior (Section D): any class that mixes this in can be
/// stamped with the time it was created and report it as text.
mixin Timestamped {
  DateTime? _stampedAt;

  void stamp() => _stampedAt ??= DateTime.now();

  String get stampedAt {
    final t = _stampedAt;
    if (t == null) return 'not stamped';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}

// --------------------- Abstract parent + subclasses ------------------------

/// Abstract parent for every record the center can lend or enroll.
abstract class LearningResource with Timestamped {
  final String _id;
  final String _title;
  bool _available = true; // encapsulated state

  LearningResource(this._id, this._title) {
    stamp();
  }

  // Controlled access through getters
  String get id => _id;
  String get title => _title;
  bool get isAvailable => _available;

  // Each subclass must provide its own implementation of these.
  String get type;
  String get details;
  int get loanDays;
  double computeFee(int daysKept);

  void checkOut() => _available = false;
  void checkIn() => _available = true;

  /// Shared method, used polymorphically through the parent type.
  String describe() =>
      '${_id.padRight(6)}${type.padRight(11)}${_title.padRight(24)}'
      '${details.padRight(34)}${(isAvailable ? "Available" : "Unavailable").padRight(12)}'
      '$stampedAt';
}

class Book extends LearningResource {
  static const double _lateFeePerDay = 0.50;
  final String _author;
  final int _pages;

  Book(String id, String title, this._author, this._pages) : super(id, title);

  @override
  String get type => 'Book';

  @override
  int get loanDays => 14;

  @override
  String get details => '$_author, $_pages pp';

  /// Free within the loan period, then a late fee per extra day.
  @override
  double computeFee(int daysKept) {
    final lateDays = daysKept - loanDays;
    return lateDays > 0 ? lateDays * _lateFeePerDay : 0.0;
  }
}

class Equipment extends LearningResource {
  final String _category;
  final double _dailyRate;

  Equipment(String id, String title, this._category, this._dailyRate)
    : super(id, title);

  @override
  String get type => 'Equipment';

  @override
  int get loanDays => 3;

  @override
  String get details => '$_category, ${formatMoney(_dailyRate)}/day';

  /// Rental charged for every day the equipment is kept.
  @override
  double computeFee(int daysKept) => _dailyRate * daysKept;
}

/// Workshops are limited by seats, so availability is seat-based.
class Workshop extends LearningResource {
  final String _instructor;
  final int _capacity;
  final double _materialsFee;
  int _enrolled = 0;

  Workshop(
    String id,
    String title,
    this._instructor,
    this._capacity,
    this._materialsFee,
  ) : super(id, title);

  @override
  String get type => 'Workshop';

  @override
  int get loanDays => 0;

  @override
  String get details => '$_instructor, seats $_enrolled/$_capacity';

  @override
  bool get isAvailable => _enrolled < _capacity;

  @override
  void checkOut() => _enrolled++;

  @override
  void checkIn() {
    if (_enrolled > 0) _enrolled--;
  }

  /// Flat materials fee, regardless of days.
  @override
  double computeFee(int daysKept) => _materialsFee;
}

// ------------------------------ Participant --------------------------------

class Participant with Timestamped {
  static const int maxItems = 3;

  final String _id;
  String _name;
  String _email;
  double _feesOwed = 0.0;
  final List<LearningResource> _items = []; // List: items currently held

  Participant(this._id, this._name, this._email) {
    if (!_email.contains('@')) {
      throw CenterException('Invalid email address: "$_email".');
    }
    stamp();
  }

  String get id => _id;
  String get name => _name;
  String get email => _email;
  double get feesOwed => _feesOwed;
  List<LearningResource> get activeItems => List.unmodifiable(_items);
  bool get canBorrow => _items.length < maxItems;

  /// Setter with validation (controlled write access).
  set email(String value) {
    if (!value.contains('@')) {
      throw CenterException('Invalid email address: "$value".');
    }
    _email = value;
  }

  bool holds(LearningResource r) => _items.contains(r);
  void addItem(LearningResource r) => _items.add(r);
  void removeItem(LearningResource r) => _items.remove(r);
  void addFee(double amount) => _feesOwed += amount;

  @override
  String toString() =>
      '${_id.padRight(6)}${_name.padRight(20)}${_email.padRight(26)}'
      '${'${_items.length}/$maxItems items'.padRight(12)}'
      '${formatMoney(_feesOwed).padRight(10)}$stampedAt';
}

// ------------------------------ Transaction --------------------------------

enum TransactionType { checkout, returned }

class Transaction with Timestamped {
  static int _counter = 0;

  final int id;
  final Participant participant;
  final LearningResource resource;
  final TransactionType type;
  final double fee;

  Transaction(this.participant, this.resource, this.type, {this.fee = 0.0})
    : id = ++_counter {
    stamp();
  }

  @override
  String toString() =>
      '#${id.toString().padRight(4)}$stampedAt  '
      '${(type == TransactionType.checkout ? "CHECKOUT" : "RETURN").padRight(10)}'
      '${participant.name.padRight(18)}${resource.title.padRight(24)}'
      '${formatMoney(fee)}';
}

// ------------------------------- Manager -----------------------------------

class CenterManager {
  final Map<String, LearningResource> _resources = {}; // Map: id -> resource
  final Map<String, Participant> _participants = {}; // Map: id -> participant
  final List<Transaction> _transactions = [];
  double _totalFees = 0.0;

  double get totalFees => _totalFees;

  void addResource(LearningResource r) {
    if (_resources.containsKey(r.id)) {
      throw CenterException('A resource with ID "${r.id}" already exists.');
    }
    _resources[r.id] = r;
  }

  void addParticipant(Participant p) {
    if (_participants.containsKey(p.id)) {
      throw CenterException('A participant with ID "${p.id}" already exists.');
    }
    _participants[p.id] = p;
  }

  Participant findParticipant(String id) =>
      _participants[id] ??
      (throw CenterException('No participant with ID "$id".'));

  LearningResource findResource(String id) =>
      _resources[id] ?? (throw CenterException('No resource with ID "$id".'));

  void checkOut(String participantId, String resourceId) {
    final p = findParticipant(participantId);
    final r = findResource(resourceId);

    if (!r.isAvailable) {
      throw CenterException('"${r.title}" is not available.');
    }
    if (!p.canBorrow) {
      throw CenterException(
        '${p.name} has reached the limit of ${Participant.maxItems} items.',
      );
    }

    r.checkOut();
    p.addItem(r);
    _transactions.add(Transaction(p, r, TransactionType.checkout));

    final due = r.loanDays > 0 ? ' Due in ${r.loanDays} days.' : '';
    print('✔ ${p.name} checked out "${r.title}".$due');
  }

  /// Returns the fee charged for this return.
  double returnResource(String participantId, String resourceId, int daysKept) {
    final p = findParticipant(participantId);
    final r = findResource(resourceId);

    if (!p.holds(r)) {
      throw CenterException('${p.name} does not currently hold "${r.title}".');
    }

    final fee = r.computeFee(daysKept); // polymorphic call
    r.checkIn();
    p.removeItem(r);
    p.addFee(fee);
    _totalFees += fee;
    _transactions.add(Transaction(p, r, TransactionType.returned, fee: fee));

    print(
      '✔ ${p.name} returned "${r.title}" after $daysKept day(s). '
      'Fee: ${formatMoney(fee)}',
    );
    return fee;
  }

  double estimateFee(String resourceId, int days) =>
      findResource(resourceId).computeFee(days);

  // ------------------------------ Displays ---------------------------------

  void showResources() {
    _header('LEARNING RESOURCES');
    if (_resources.isEmpty) {
      print('(none registered)');
      return;
    }
    // Polymorphism: Book, Equipment and Workshop handled as LearningResource.
    for (final LearningResource r in _resources.values) {
      print(r.describe());
    }
  }

  void showParticipants() {
    _header('PARTICIPANTS');
    if (_participants.isEmpty) {
      print('(none registered)');
      return;
    }
    for (final p in _participants.values) {
      print(p);
    }
  }

  void showTransactions() {
    _header('TRANSACTION HISTORY');
    if (_transactions.isEmpty) {
      print('(no transactions yet)');
      return;
    }
    for (final t in _transactions) {
      print(t);
    }
  }

  void showSummary() {
    _header('SUMMARY');
    final available = _resources.values.where((r) => r.isAvailable).length;
    final returns = _transactions
        .where((t) => t.type == TransactionType.returned)
        .length;
    final average = returns == 0 ? 0.0 : _totalFees / returns;

    final byType = <String, int>{};
    for (final r in _resources.values) {
      byType[r.type] = (byType[r.type] ?? 0) + 1;
    }

    print('Resources:      ${_resources.length} ($available available)');
    byType.forEach((t, n) => print('  - $t: $n'));
    print('Participants:   ${_participants.length}');
    print('Transactions:   ${_transactions.length}');
    print(
      'Fees collected: ${formatMoney(_totalFees)} '
      '(average ${formatMoney(average)} per return)',
    );
  }

  void _header(String title) {
    print('\n${'=' * 112}\n $title\n${'=' * 112}');
  }
}

// ---------------------- User-defined helper functions ----------------------

/// Formats a number as currency text, e.g. 3.5 -> "$3.50".
String formatMoney(double amount) => '\$${amount.toStringAsFixed(2)}';

/// Thrown when the scripted input list runs out.
class InputEnded implements Exception {}

/// Simulated console input (DartPad cannot read the keyboard).
/// Each prompt consumes the next item. Some answers are deliberately
/// invalid to demonstrate the error handling. Edit freely!
final List<String> scriptedInputs = [
  '7', // view resources
  'abc', // invalid menu choice
  '', // empty menu choice
  // Register a book (first "Pages" answer is invalid)
  '1', 'B003', 'Flutter Basics', 'Google', 'abc', '250',
  // Register equipment (first "Daily rate" answer is invalid)
  '2', 'E003', 'Tablet', 'Computing', 'free', '1.75',
  // Register workshop (capacity 0 is invalid, then 5)
  '3', 'W002', 'Dart Workshop', 'Mr. Reyes', '0', '5', '10',
  // Register participant with a bad email, then a good one
  '4', 'P003', 'Carla Diaz', 'carla-at-email.com',
  '4', 'P003', 'Carla Diaz', 'carla@email.com',
  // Check outs: success, unavailable item, unknown participant, workshop
  '5', 'P001', 'E001',
  '5', 'P002', 'E001',
  '5', 'P009', 'B001',
  '5', 'P001', 'W001',
  // Returns: equipment kept 5 days (fee), item not held (error)
  '6', 'P001', 'E001', '5',
  '6', 'P001', 'B001', '3',
  // Estimate a late fee for a book kept 20 days
  '11', 'B001', '20',
  // Update an email
  '12', 'P002', 'bob@new.com',
  // View records
  '7', '8', '9', '10',
  '0', // exit
];
int _inputIndex = 0;

/// Reads one answer from the scripted input and echoes it.
/// (For real keyboard input on your own computer, see the note at the end.)
String readLine(String label) {
  if (_inputIndex >= scriptedInputs.length) throw InputEnded();
  final line = scriptedInputs[_inputIndex++].trim();
  print('$label: $line');
  return line;
}

/// Keeps asking until the user types something non-empty.
String readText(String label) {
  while (true) {
    final value = readLine(label);
    if (value.isNotEmpty) return value;
    print('✘ Input cannot be empty. Please try again.');
  }
}

/// Keeps asking until the user types a whole number >= [min].
int readInt(String label, {int min = 0}) {
  while (true) {
    final value = int.tryParse(readLine(label));
    if (value != null && value >= min) return value;
    print('✘ Please enter a whole number of at least $min.');
  }
}

/// Keeps asking until the user types a non-negative decimal number.
double readDouble(String label) {
  while (true) {
    final value = double.tryParse(readLine(label));
    if (value != null && value >= 0) return value;
    print('✘ Please enter a valid amount (0 or more).');
  }
}

void seedData(CenterManager m) {
  m.addResource(Book('B001', 'Dart in Action', 'Chris Buckett', 400));
  m.addResource(Book('B002', 'Clean Code', 'Robert C. Martin', 464));
  m.addResource(Equipment('E001', 'Laptop (Dell)', 'Computing', 2.50));
  m.addResource(Equipment('E002', 'Projector', 'Presentation', 4.00));
  m.addResource(Workshop('W001', 'Intro to Flutter', 'Ms. Tan', 2, 15.00));

  m.addParticipant(Participant('P001', 'Alice Lim', 'alice@email.com'));
  m.addParticipant(Participant('P002', 'Bob Chen', 'bob@email.com'));
}

void printTitle() {
  print('╔══════════════════════════════════════════════════╗');
  print('║   COMMUNITY LEARNING CENTER MANAGEMENT SYSTEM    ║');
  print('╚══════════════════════════════════════════════════╝');
}

void printMenu() {
  print('''

------------------- MAIN MENU -------------------
  1. Register book
  2. Register equipment
  3. Register workshop
  4. Register participant
  5. Check out / enroll
  6. Return / withdraw (calculates fee)
  7. View resources
  8. View participants
  9. View transactions
 10. View summary
 11. Estimate fee for a resource
 12. Update participant email
  0. Exit
-------------------------------------------------''');
}

// --------------------------------- main ------------------------------------

void main() {
  final center = CenterManager();
  seedData(center);

  printTitle();
  print('Sample data loaded: 5 resources, 2 participants.');

  var running = true;
  try {
    while (running) {
      printMenu();
      final choice = readLine('Choose an option');

      try {
        switch (choice) {
          case '1':
            center.addResource(
              Book(
                readText('Book ID'),
                readText('Title'),
                readText('Author'),
                readInt('Pages', min: 1),
              ),
            );
            print('✔ Book registered.');
          case '2':
            center.addResource(
              Equipment(
                readText('Equipment ID'),
                readText('Name'),
                readText('Category'),
                readDouble('Daily rate'),
              ),
            );
            print('✔ Equipment registered.');
          case '3':
            center.addResource(
              Workshop(
                readText('Workshop ID'),
                readText('Title'),
                readText('Instructor'),
                readInt('Capacity (seats)', min: 1),
                readDouble('Materials fee'),
              ),
            );
            print('✔ Workshop registered.');
          case '4':
            center.addParticipant(
              Participant(
                readText('Participant ID'),
                readText('Name'),
                readText('Email'),
              ),
            );
            print('✔ Participant registered.');
          case '5':
            center.checkOut(
              readText('Participant ID'),
              readText('Resource ID'),
            );
          case '6':
            center.returnResource(
              readText('Participant ID'),
              readText('Resource ID'),
              readInt('Days kept'),
            );
          case '7':
            center.showResources();
          case '8':
            center.showParticipants();
          case '9':
            center.showTransactions();
          case '10':
            center.showSummary();
          case '11':
            final fee = center.estimateFee(
              readText('Resource ID'),
              readInt('Days kept'),
            );
            print('Estimated fee: ${formatMoney(fee)}');
          case '12':
            center.findParticipant(readText('Participant ID')).email = readText(
              'New email',
            );
            print('✔ Email updated.');
          case '0':
            running = false;
            print('Thank you for using the system. Goodbye!');
          default:
            print('✘ "$choice" is not a valid option. Please choose 0-12.');
        }
      } on CenterException catch (e) {
        print('✘ Error: $e');
      }
    }
  } on InputEnded {
    print('\n(End of scripted input.)');
  }
}

// ---------------------------------------------------------------------------
// NOTE: To use real keyboard input on your own computer (not DartPad):
//   1. Add   import 'dart:io';   at the top of the file.
//   2. Replace the body of readLine() with:
//        stdout.write('$label: ');
//        final line = stdin.readLineSync();
//        if (line == null) exit(0);
//        return line.trim();
//   3. Run with:  dart run learning_center.dart
// ---------------------------------------------------------------------------
