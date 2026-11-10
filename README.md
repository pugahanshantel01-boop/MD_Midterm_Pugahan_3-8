# Community Learning Center Management System

A console-based application written in **Dart** that registers learning resources and
participants, processes check-out / return transactions, calculates fees, and displays
organized records. It demonstrates fundamental Dart syntax and object-oriented design in a
single working application.

> Mobile Development • Midterm Laboratory Examination

---

## Application Features

### Core functionality
- **Register learning resources** of three kinds: books, equipment, and workshops.
- **Register participants** with name and (validated) email.
- **Check out / enroll** resources, with rules enforced automatically.
- **Return / withdraw** resources and automatically **calculate fees**.
- **View organized records**: resources, participants, transaction history, and a summary.
- **Estimate fees** for any resource before borrowing.
- **Update a participant's email** (validated through a setter).
- **Sample data** is preloaded so you can try the app immediately.

### Menu

| # | Action | # | Action |
|---|--------|---|--------|
| 1 | Register book | 7 | View resources |
| 2 | Register equipment | 8 | View participants |
| 3 | Register workshop | 9 | View transactions |
| 4 | Register participant | 10 | View summary |
| 5 | Check out / enroll | 11 | Estimate fee for a resource |
| 6 | Return / withdraw (calculates fee) | 12 | Update participant email |
| | | 0 | Exit |

### Business rules

| Rule | Detail |
|------|--------|
| Item limit | A participant may hold at most **3** items at a time |
| Availability | A resource that is already checked out cannot be borrowed again |
| Workshop seats | Workshops are limited by capacity (seats filled / total seats) |
| Unique IDs | Duplicate resource or participant IDs are rejected |
| Email check | Emails must contain `@` |

### Fee calculation

| Resource | Loan period | Fee on return |
|----------|-------------|---------------|
| Book | 14 days | Free within 14 days, then **$0.50 per extra day** |
| Equipment | 3 days | **Daily rate × days kept** |
| Workshop | – | **Flat materials fee** |

Example: Laptop (rate $2.50/day) kept for 5 days → **$12.50**.

### Input validation and error handling
- Invalid or empty menu choices show a message and return to the menu.
- Empty text, non-numeric numbers, and negative amounts are re-prompted.
- Business-rule violations raise a custom `CenterException`, which is caught so the
  program never crashes.
- Closing the input stream (Ctrl+D / Ctrl+Z) ends the program cleanly.

---

## Object-Oriented Design

| Concept | Where it appears |
|---------|------------------|
| Abstract class | `LearningResource` (abstract parent of all resources) |
| Inheritance | `Book`, `Equipment`, `Workshop` extend `LearningResource` |
| Polymorphism | Resources are handled as `LearningResource`; each subclass supplies its own `type`, `details`, `loanDays`, and `computeFee()` |
| Mixin | `Timestamped` adds `stamp()` / `stampedAt` to resources, participants, and transactions |
| Encapsulation | Private fields (`_id`, `_available`, `_feesOwed`, …), getters, a validating `email` setter, and an unmodifiable view of `activeItems` |
| Constructors | Named/positional constructors, initializer lists, constructor bodies with validation |
| Collections | `Map<String, …>` for resources and participants; `List` for transactions and held items |
| Enums | `TransactionType` (`checkout`, `returned`) |
| Custom exception | `CenterException`, `InputEnded` |
| Functions | `formatMoney`, `readLine`, `readText`, `readInt`, `readDouble`, `seedData`, `printTitle`, `printMenu` |

---

## How It Works

### 1. Program flow

```
main()
 ├─ create CenterManager and load sample data (seedData)
 ├─ print the title banner (printTitle)
 └─ loop until the user chooses 0
     ├─ print the menu (printMenu)
     ├─ read the choice (readLine)
     ├─ switch (choice) → call the matching action
     └─ catch CenterException → print "✘ Error: ..." and show the menu again
```

`main()` is the only place that talks to the user. It reads input, picks an action with a
`switch`, and hands the real work to `CenterManager`. Every rule violation is thrown as a
`CenterException` deep inside the classes and caught once in this loop, so a mistake never
crashes the program. An outer `try/on InputEnded` ends the program cleanly if the input
stream is closed.

### 2. Input helper functions

| Function | What it does |
|----------|--------------|
| `readLine(label)` | Prints a prompt and returns one trimmed line of input |
| `readText(label)` | Repeats the prompt until the answer is not empty |
| `readInt(label, min:)` | Repeats until the answer is a whole number ≥ `min` |
| `readDouble(label)` | Repeats until the answer is a valid number ≥ 0 |
| `formatMoney(amount)` | Returns text such as `$12.50` using `toStringAsFixed(2)` |

Because these functions loop until the input is valid, the classes can assume they always
receive clean values.

### 3. Classes and their roles

**`LearningResource` (abstract parent)**
Holds the fields every resource shares: `_id`, `_title` and `_available` (all private, read
through getters). It declares four members that each subclass must define: `type`, `details`,
`loanDays` and `computeFee(daysKept)`. It also provides `checkOut()`, `checkIn()` and
`describe()`, which formats one table row for display.

**`Book`, `Equipment`, `Workshop` (subclasses)**
Each one fills in the abstract members in its own way:

| | `loanDays` | `computeFee(daysKept)` | Availability |
|---|---|---|---|
| `Book` | 14 | `(daysKept - 14) × 0.50` if late, otherwise `0` | on/off flag |
| `Equipment` | 3 | `dailyRate × daysKept` | on/off flag |
| `Workshop` | 0 | flat materials fee | `enrolled < capacity` (overrides `isAvailable`, and `checkOut()` / `checkIn()` change the seat count) |

**`Participant`**
Stores `_id`, `_name`, `_email`, `_feesOwed` and a private `List<LearningResource> _items`
of what the person currently holds. The constructor and the `email` setter both reject
addresses without `@`. `canBorrow` compares the number of held items with `maxItems` (3).
`activeItems` returns an unmodifiable copy, so outside code cannot change the list directly.

**`Transaction`**
One log entry: who, which resource, checkout or return, and the fee. A static counter
(`_counter`) gives each transaction a unique, increasing ID.

**`Timestamped` (mixin)**
Adds a private `_stampedAt` field plus `stamp()` and `stampedAt`. It is mixed into
`LearningResource`, `Participant` and `Transaction`, so all three record when they were
created without repeating the code. `stamp()` uses `??=`, so a record is stamped only once.

**`CenterManager`**
The coordinator. It owns:
- `Map<String, LearningResource> _resources` for fast lookup by ID
- `Map<String, Participant> _participants` for fast lookup by ID
- `List<Transaction> _transactions` for the history, in order
- `_totalFees`, the running total of all fees

### 4. What happens on a check-out (menu option 5)

1. `main()` asks for a participant ID and a resource ID.
2. `CenterManager.checkOut()` looks up both in the maps. A missing ID throws
   `CenterException`.
3. If `resource.isAvailable` is false, it throws "not available".
4. If `participant.canBorrow` is false, it throws "reached the limit of 3 items".
5. Otherwise it calls `resource.checkOut()`, adds the resource to the participant's list,
   and records a `Transaction` of type `checkout`.
6. It prints a confirmation, including the due date in days when the resource has a loan period.

### 5. What happens on a return (menu option 6)

1. `main()` asks for the participant ID, the resource ID and the number of days kept.
2. The manager checks the participant actually holds the resource, otherwise it throws.
3. It calls `resource.computeFee(daysKept)`. This is **polymorphism**: the same call runs the
   `Book`, `Equipment` or `Workshop` version depending on the real object.
4. It calls `resource.checkIn()`, removes the resource from the participant, adds the fee to
   the participant's balance and to `_totalFees`, and logs a `returned` transaction.

Worked example: Alice checks out the laptop (`E001`, $2.50/day) and returns it after 5 days.
`Equipment.computeFee(5)` returns `2.50 × 5 = 12.50`, so her balance becomes `$12.50`.

### 6. Displaying records

- `showResources()` loops over the `_resources` values typed as `LearningResource` and prints
  `describe()` for each. Books, equipment and workshops share one loop, and each prints its own details.
- `showParticipants()` and `showTransactions()` loop over their collections and print each
  object's `toString()`.
- `showSummary()` counts available resources with `where`, groups resources by type in a
  `Map<String, int>`, and computes the average fee per return as
  `_totalFees / returns` (guarded against dividing by zero).

### 7. Error handling at a glance

| Problem | How it is handled |
|---------|-------------------|
| Unknown menu choice or empty input at the menu | `default` branch of the `switch` prints a message |
| Empty text, non-numeric or negative numbers | `readText` / `readInt` / `readDouble` ask again |
| Unknown ID, unavailable item, item limit, item not held, duplicate ID, bad email | `CenterException` is thrown and caught in `main()` |
| Input stream closed | `InputEnded` is caught and the program ends cleanly |

---

## Project Structure

```
learning-center-management/
├── bin/
│   └── learning_center.dart          # Interactive version (keyboard input)
├── dartpad/
│   └── learning_center_dartpad.dart  # Browser version (scripted input)
├── pubspec.yaml
├── .gitignore
└── README.md
```

---

## How to Run

### Option 1: Locally (interactive, keyboard input)

**Requirements:** [Dart SDK 3.0 or newer](https://dart.dev/get-dart)

```bash
# 1. Clone the repository
git clone https://github.com/<your-username>/learning-center-management.git
cd learning-center-management

# 2. Check your Dart version
dart --version

# 3. Run the application
dart run bin/learning_center.dart
```

Type a menu number and press **Enter**. Choose `0` to exit.

Try this sequence with the sample data:
1. `5` → `P001` → `E001` (Alice checks out the laptop)
2. `6` → `P001` → `E001` → `5` (returned after 5 days, fee **$12.50**)
3. `9` to see the transaction history, `10` for the summary

### Option 2: DartPad (browser, no installation)

DartPad cannot read keyboard input, so this version reads its answers from a scripted list
(`scriptedInputs`) and echoes them to the console as if typed.

1. Open <https://dartpad.dev>.
2. Copy the entire contents of `dartpad/learning_center_dartpad.dart` into the editor.
3. Click **Run**.

The script demonstrates valid and invalid menu choices, registering all resource types,
rejected input, successful and failed check-outs, a fee calculation, and all record views.
Edit the `scriptedInputs` list to test other scenarios.

---

## Author

Your Name – Section / Course Code
