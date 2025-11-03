import 'package:hive/hive.dart';

part 'transaction_model.g.dart';

@HiveType(typeId: 4)
class TransactionModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String category;

  @HiveField(3)
  double amount;

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  bool isExpense;

  @HiveField(6)
  String? notes;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime updatedAt;

  TransactionModel({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.isExpense,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor untuk create new transaction
  factory TransactionModel.create({
    required String title,
    required String category,
    required double amount,
    required DateTime date,
    required bool isExpense,
    String? notes,
  }) {
    final now = DateTime.now();
    return TransactionModel(
      id: now.millisecondsSinceEpoch.toString(),
      title: title,
      category: category,
      amount: amount,
      date: date,
      isExpense: isExpense,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Update transaction
  void updateTransaction({
    String? title,
    String? category,
    double? amount,
    DateTime? date,
    bool? isExpense,
    String? notes,
  }) {
    if (title != null) this.title = title;
    if (category != null) this.category = category;
    if (amount != null) this.amount = amount;
    if (date != null) this.date = date;
    if (isExpense != null) this.isExpense = isExpense;
    this.notes = notes;
    this.updatedAt = DateTime.now();
    save();
  }

  // Get icon based on category
  String getCategoryIcon() {
    final expenseIcons = {
      'Transportation': '🚗',
      'Food': '🍔',
      'Clothes': '👕',
      'Electric': '⚡',
      'Entertainment': '🎮',
      'Health': '🏥',
      'Education': '📚',
      'Shopping': '🛒',
      'Social': '👥',
      'Other': '📦',
    };

    final incomeIcons = {
      'Salary': '💰',
      'Part-time': '💼',
      'Investment': '📈',
      'Gift': '🎁',
      'Business': '🏢',
      'Freelance': '💻',
      'Other': '💵',
    };

    if (isExpense) {
      return expenseIcons[category] ?? '📦';
    } else {
      return incomeIcons[category] ?? '💵';
    }
  }

  // Get formatted date
  String getFormattedDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Hari Ini';
    } else if (transactionDate == today.subtract(const Duration(days: 1))) {
      return 'Kemarin';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Copy with method
  TransactionModel copyWith({
    String? id,
    String? title,
    String? category,
    double? amount,
    DateTime? date,
    bool? isExpense,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      isExpense: isExpense ?? this.isExpense,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Format amount dengan currency
  String getFormattedAmount() {
    final formatter = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    );
    return 'Rp $formatter';
  }

  @override
  String toString() {
    return 'TransactionModel(title: $title, amount: $amount, isExpense: $isExpense, date: ${getFormattedDate()})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Budget Model
@HiveType(typeId: 5)
class BudgetModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String category;

  @HiveField(2)
  double amount;

  @HiveField(3)
  String period; // 'daily', 'weekly', 'monthly'

  @HiveField(4)
  DateTime startDate;

  @HiveField(5)
  DateTime endDate;

  @HiveField(6)
  bool isActive;

  @HiveField(7)
  DateTime createdAt;

  BudgetModel({
    required this.id,
    required this.category,
    required this.amount,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.createdAt,
  });

  // Get spent amount for this budget
  double getSpentAmount(List<TransactionModel> transactions) {
    return transactions
        .where((t) =>
    t.isExpense &&
        t.category == category &&
        t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
        t.date.isBefore(endDate.add(const Duration(days: 1)))
    )
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // Get remaining budget
  double getRemainingBudget(List<TransactionModel> transactions) {
    return amount - getSpentAmount(transactions);
  }

  // Get percentage used
  double getPercentageUsed(List<TransactionModel> transactions) {
    final spent = getSpentAmount(transactions);
    return amount > 0 ? (spent / amount).clamp(0.0, 1.0) : 0.0;
  }

  // Check if over budget
  bool isOverBudget(List<TransactionModel> transactions) {
    return getSpentAmount(transactions) > amount;
  }

  // Format budget amount
  String getFormattedAmount() {
    final formatter = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    );
    return 'Rp $formatter';
  }

  // Get period label in Indonesian
  String getPeriodLabel() {
    switch (period) {
      case 'daily':
        return 'Harian';
      case 'weekly':
        return 'Mingguan';
      case 'monthly':
        return 'Bulanan';
      default:
        return period;
    }
  }

  @override
  String toString() {
    return 'BudgetModel(category: $category, amount: $amount, period: $period, isActive: $isActive)';
  }
}

// Financial Summary Model
@HiveType(typeId: 6)
class FinancialSummary extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  double totalIncome;

  @HiveField(2)
  double totalExpense;

  @HiveField(3)
  double balance;

  @HiveField(4)
  Map<String, double> expenseByCategory;

  @HiveField(5)
  Map<String, double> incomeByCategory;

  FinancialSummary({
    required this.date,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.expenseByCategory,
    required this.incomeByCategory,
  });

  // Calculate from transactions
  factory FinancialSummary.fromTransactions(
      List<TransactionModel> transactions,
      DateTime date,
      ) {
    double totalIncome = 0;
    double totalExpense = 0;
    Map<String, double> expenseByCategory = {};
    Map<String, double> incomeByCategory = {};

    for (var transaction in transactions) {
      if (transaction.isExpense) {
        totalExpense += transaction.amount;
        expenseByCategory[transaction.category] =
            (expenseByCategory[transaction.category] ?? 0) + transaction.amount;
      } else {
        totalIncome += transaction.amount;
        incomeByCategory[transaction.category] =
            (incomeByCategory[transaction.category] ?? 0) + transaction.amount;
      }
    }

    return FinancialSummary(
      date: date,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      balance: totalIncome - totalExpense,
      expenseByCategory: expenseByCategory,
      incomeByCategory: incomeByCategory,
    );
  }

  // Get top expense categories
  List<MapEntry<String, double>> getTopExpenseCategories({int limit = 5}) {
    var sorted = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  // Get savings rate
  double getSavingsRate() {
    return totalIncome > 0 ? (balance / totalIncome).clamp(0.0, 1.0) : 0.0;
  }
}