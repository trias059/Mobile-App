// File: lib/pages/money_management_page.dart
// Fixed overflow issues with proper layout constraints

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '/model/transaction_model.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class MoneyManagementPage extends StatefulWidget {
  const MoneyManagementPage({super.key});

  @override
  State<MoneyManagementPage> createState() => _MoneyManagementPageState();
}

class _MoneyManagementPageState extends State<MoneyManagementPage> {
  late Box<TransactionModel> transactionBox;
  late Box settingsBox;
  String _selectedFilter = 'Semua';
  bool _isLoading = true;

  // Manual balance tracking
  double _manualBalance = 0.0;
  double _monthlyIncomeTarget = 0.0;
  double _monthlyExpenseLimit = 0.0;

  // Transaction categories
  final Map<String, IconData> expenseCategories = {
    'Transportation': Icons.directions_car,
    'Food': Icons.restaurant,
    'Clothes': Icons.checkroom,
    'Electric': Icons.electrical_services,
    'Entertainment': Icons.sports_esports,
    'Health': Icons.local_hospital,
    'Education': Icons.school,
    'Shopping': Icons.shopping_cart,
    'Social': Icons.people,
    'Other': Icons.category,
  };

  final Map<String, IconData> incomeCategories = {
    'Salary': Icons.account_balance_wallet,
    'Part-time': Icons.work_outline,
    'Investment': Icons.trending_up,
    'Gift': Icons.card_giftcard,
    'Business': Icons.business,
    'Freelance': Icons.computer,
    'Other': Icons.attach_money,
  };

  @override
  void initState() {
    super.initState();
    _initializeBoxes();
  }

  Future<void> _initializeBoxes() async {
    try {
      transactionBox = await Hive.openBox<TransactionModel>('transactions');
      settingsBox = await Hive.openBox('money_settings');

      // Load saved values
      _manualBalance = settingsBox.get('manual_balance', defaultValue: 0.0);
      _monthlyIncomeTarget = settingsBox.get('monthly_income_target', defaultValue: 0.0);
      _monthlyExpenseLimit = settingsBox.get('monthly_expense_limit', defaultValue: 0.0);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing boxes: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  // CLEAR ALL DATA FUNCTION
  Future<void> _clearAllData() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ Hapus Semua Data'),
        content: const Text(
            'Yakin ingin menghapus SEMUA transaksi dan pengaturan?\n\n'
                'Tindakan ini tidak dapat dibatalkan!'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await transactionBox.clear();
                await settingsBox.clear();

                setState(() {
                  _manualBalance = 0.0;
                  _monthlyIncomeTarget = 0.0;
                  _monthlyExpenseLimit = 0.0;
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Semua data berhasil dihapus!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus Semua', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Calculate totals
  Map<String, double> calculateTotals() {
    final transactions = transactionBox.values.toList();
    double totalIncome = 0;
    double totalExpense = 0;

    for (var transaction in transactions) {
      if (transaction.isExpense) {
        totalExpense += transaction.amount;
      } else {
        totalIncome += transaction.amount;
      }
    }

    double balance = _manualBalance > 0 ? _manualBalance : (totalIncome - totalExpense);

    return {
      'balance': balance,
      'income': totalIncome,
      'expense': totalExpense,
      'manual_balance': _manualBalance,
      'income_target': _monthlyIncomeTarget,
      'expense_limit': _monthlyExpenseLimit,
    };
  }

  List<TransactionModel> get filteredTransactions {
    final transactions = transactionBox.values.toList();
    transactions.sort((a, b) => b.date.compareTo(a.date));

    switch (_selectedFilter) {
      case 'Hari Ini':
        final today = DateTime.now();
        return transactions.where((t) =>
        t.date.year == today.year &&
            t.date.month == today.month &&
            t.date.day == today.day
        ).toList();
      case 'Minggu':
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        return transactions.where((t) => t.date.isAfter(weekAgo)).toList();
      case 'Bulan':
        final monthAgo = DateTime.now().subtract(const Duration(days: 30));
        return transactions.where((t) => t.date.isAfter(monthAgo)).toList();
      default:
        return transactions;
    }
  }

  Map<String, List<TransactionModel>> get groupedTransactions {
    Map<String, List<TransactionModel>> grouped = {};
    for (var transaction in filteredTransactions) {
      final dateKey = _getDateKey(transaction.date);
      grouped.putIfAbsent(dateKey, () => []).add(transaction);
    }
    return grouped;
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Hari Ini';
    } else if (transactionDate == today.subtract(const Duration(days: 1))) {
      return 'Kemarin';
    } else {
      return DateFormat('d MMMM yyyy', 'id_ID').format(date);
    }
  }

  // Edit Balance Dialog
  void _showEditBalanceDialog() {
    final balanceController = TextEditingController(text: _manualBalance.toString());
    final incomeTargetController = TextEditingController(text: _monthlyIncomeTarget.toString());
    final expenseLimitController = TextEditingController(text: _monthlyExpenseLimit.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Pengaturan Keuangan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: balanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Saldo Manual',
                  prefixText: 'Rp ',
                  helperText: 'Kosongkan untuk otomatis',
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: incomeTargetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Target Income Bulanan',
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: expenseLimitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Limit Expense Bulanan',
                  prefixText: 'Rp ',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _manualBalance = double.tryParse(balanceController.text) ?? 0.0;
                _monthlyIncomeTarget = double.tryParse(incomeTargetController.text) ?? 0.0;
                _monthlyExpenseLimit = double.tryParse(expenseLimitController.text) ?? 0.0;
              });

              settingsBox.put('manual_balance', _manualBalance);
              settingsBox.put('monthly_income_target', _monthlyIncomeTarget);
              settingsBox.put('monthly_expense_limit', _monthlyExpenseLimit);

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pengaturan berhasil disimpan!')),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // Generate PDF Report
  Future<void> _generatePDFReport() async {
    try {
      final totals = calculateTotals();
      final transactions = filteredTransactions;

      if (transactions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Belum ada transaksi untuk dibuat laporan')),
        );
        return;
      }

      String reportContent = _generateReportContent(totals, transactions);

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/laporan_keuangan_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(reportContent);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Laporan Keuangan - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan berhasil dibuat dan dibagikan!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error membuat laporan: $e')),
      );
    }
  }

  String _generateReportContent(Map<String, double> totals, List<TransactionModel> transactions) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    final now = DateTime.now();

    StringBuffer report = StringBuffer();

    report.writeln('=' * 50);
    report.writeln('LAPORAN KEUANGAN PRIBADI');
    report.writeln('Tanggal: ${DateFormat('dd MMMM yyyy', 'id_ID').format(now)}');
    report.writeln('Filter: $_selectedFilter');
    report.writeln('=' * 50);
    report.writeln();

    report.writeln('RINGKASAN KEUANGAN');
    report.writeln('-' * 30);
    report.writeln('Saldo Total       : ${formatter.format(totals['balance'])}');
    report.writeln('Total Income      : ${formatter.format(totals['income'])}');
    report.writeln('Total Expense     : ${formatter.format(totals['expense'])}');

    if (totals['income_target']! > 0) {
      double incomeProgress = (totals['income']! / totals['income_target']!) * 100;
      report.writeln('Target Income     : ${formatter.format(totals['income_target'])}');
      report.writeln('Progress Income   : ${incomeProgress.toStringAsFixed(1)}%');
    }

    if (totals['expense_limit']! > 0) {
      double expenseProgress = (totals['expense']! / totals['expense_limit']!) * 100;
      report.writeln('Limit Expense     : ${formatter.format(totals['expense_limit'])}');
      report.writeln('Usage Expense     : ${expenseProgress.toStringAsFixed(1)}%');
    }

    report.writeln();
    report.writeln('RINCIAN TRANSAKSI');
    report.writeln('-' * 30);

    final grouped = groupedTransactions;
    for (var dateKey in grouped.keys) {
      report.writeln('\n$dateKey:');
      for (var transaction in grouped[dateKey]!) {
        String type = transaction.isExpense ? 'OUT' : 'IN ';
        String amount = formatter.format(transaction.amount);
        report.writeln('  [$type] $amount - ${transaction.title}');
        if (transaction.notes != null && transaction.notes!.isNotEmpty) {
          report.writeln('       Note: ${transaction.notes}');
        }
      }
    }

    report.writeln('\n' + '=' * 50);
    report.writeln('Laporan dibuat otomatis oleh Lisku App');
    report.writeln('${DateFormat('dd/MM/yyyy HH:mm').format(now)}');

    return report.toString();
  }

  void _showAddTransactionDialog({bool isExpense = true, TransactionModel? editTransaction}) {
    final titleController = TextEditingController(text: editTransaction?.title ?? '');
    final amountController = TextEditingController(text: editTransaction?.amount.toString() ?? '');
    final notesController = TextEditingController(text: editTransaction?.notes ?? '');
    String selectedCategory = editTransaction?.category ?? (isExpense ? 'Food' : 'Salary');
    final categories = isExpense ? expenseCategories : incomeCategories;
    DateTime selectedDate = editTransaction?.date ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  editTransaction != null
                      ? 'Edit Transaksi'
                      : (isExpense ? 'Tambah Pengeluaran' : 'Tambah Pemasukan'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Title Input
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Judul Transaksi',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // Category Selection
                const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories.keys.elementAt(index);
                      final icon = categories.values.elementAt(index);
                      final isSelected = category == selectedCategory;

                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            selectedCategory = category;
                          });
                        },
                        child: Container(
                          width: 70,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isExpense ? Colors.red[50] : Colors.green[50])
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isSelected
                                  ? (isExpense ? Colors.red : Colors.green)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                icon,
                                color: isSelected
                                    ? (isExpense ? Colors.red : Colors.green)
                                    : Colors.grey[600],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                category,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isSelected
                                      ? (isExpense ? Colors.red : Colors.green)
                                      : Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Amount Input
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Jumlah',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // Date Picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setModalState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.grey),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('d MMMM yyyy', 'id_ID').format(selectedDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // Notes Input
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Catatan (Opsional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final amount = double.tryParse(amountController.text);
                          if (amount != null && amount > 0 && titleController.text.isNotEmpty) {
                            if (editTransaction != null) {
                              editTransaction.updateTransaction(
                                title: titleController.text,
                                category: selectedCategory,
                                amount: amount,
                                date: selectedDate,
                                isExpense: isExpense,
                                notes: notesController.text.isEmpty ? null : notesController.text,
                              );
                            } else {
                              final transaction = TransactionModel.create(
                                title: titleController.text,
                                category: selectedCategory,
                                amount: amount,
                                date: selectedDate,
                                isExpense: isExpense,
                                notes: notesController.text.isEmpty ? null : notesController.text,
                              );
                              transactionBox.add(transaction);
                            }

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    editTransaction != null
                                        ? 'Transaksi berhasil diupdate'
                                        : (isExpense ? 'Pengeluaran berhasil ditambahkan' : 'Pemasukan berhasil ditambahkan')
                                ),
                                backgroundColor: isExpense ? Colors.red : Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Mohon isi semua field yang diperlukan'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isExpense ? Colors.red : Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          editTransaction != null ? 'Update' : 'Simpan',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deleteTransaction(TransactionModel transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: Text('Yakin ingin menghapus transaksi "${transaction.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              transaction.delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transaksi berhasil dihapus')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF4DB6AC),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 20),
                Text(
                  'Memuat data keuangan...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF4DB6AC),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: transactionBox.listenable(),
          builder: (context, Box<TransactionModel> box, _) {
            final totals = calculateTotals();

            return Column(
              children: [
                // Header Section - Fixed height
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // App Bar
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, color: Colors.white),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Pengeluaran Pribadi',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: _showEditBalanceDialog,
                            tooltip: 'Edit Saldo',
                          ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                            onPressed: _generatePDFReport,
                            tooltip: 'Buat Laporan PDF',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_sweep, color: Colors.white),
                            onPressed: _clearAllData,
                            tooltip: 'Hapus Semua Data',
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Balance Cards - Fixed height
                      SizedBox(
                        height: 100,
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildBalanceCard(
                                title: 'Saldo',
                                amount: formatter.format(totals['balance']),
                                icon: Icons.account_balance_wallet,
                                color: Colors.white,
                                onTap: _showEditBalanceDialog,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildBalanceCard(
                                title: 'Income',
                                amount: formatter.format(totals['income']),
                                icon: Icons.arrow_downward,
                                color: Colors.green[100]!,
                                textColor: Colors.green[700]!,
                                subtitle: totals['income_target']! > 0
                                    ? '${((totals['income']! / totals['income_target']!) * 100).toStringAsFixed(0)}% target'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildBalanceCard(
                                title: 'Expenses',
                                amount: formatter.format(totals['expense']),
                                icon: Icons.arrow_upward,
                                color: Colors.red[100]!,
                                textColor: Colors.red[700]!,
                                subtitle: totals['expense_limit']! > 0
                                    ? '${((totals['expense']! / totals['expense_limit']!) * 100).toStringAsFixed(0)}% limit'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Transaction List Section - Flexible to fill remaining space
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    child: Column(
                      children: [
                        // Filter Pills - Fixed height
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Riwayat Transaksi',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 15),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildFilterChip('Semua'),
                                    const SizedBox(width: 8),
                                    _buildFilterChip('Hari Ini'),
                                    const SizedBox(width: 8),
                                    _buildFilterChip('Minggu'),
                                    const SizedBox(width: 8),
                                    _buildFilterChip('Bulan'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Transaction List - Flexible to fill remaining space
                        Expanded(
                          child: groupedTransactions.isEmpty
                              ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
                                const SizedBox(height: 20),
                                Text(
                                  'Belum ada transaksi',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Tap + untuk menambah transaksi',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[400],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (transactionBox.isNotEmpty)
                                  ElevatedButton.icon(
                                    onPressed: _clearAllData,
                                    icon: const Icon(Icons.delete_sweep),
                                    label: const Text('Hapus Semua Data Lama'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          )
                              : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: groupedTransactions.length,
                            itemBuilder: (context, dateIndex) {
                              final dateKey = groupedTransactions.keys.elementAt(dateIndex);
                              final dayTransactions = groupedTransactions[dateKey]!;

                              // Calculate daily total
                              double dailyExpense = 0;
                              double dailyIncome = 0;
                              for (var t in dayTransactions) {
                                if (t.isExpense) {
                                  dailyExpense += t.amount;
                                } else {
                                  dailyIncome += t.amount;
                                }
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date Header
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Row(
                                      children: [
                                        Text(
                                          dateKey,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (dailyIncome > 0)
                                          Text(
                                            '+${formatter.format(dailyIncome)}',
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        if (dailyIncome > 0 && dailyExpense > 0)
                                          const SizedBox(width: 10),
                                        if (dailyExpense > 0)
                                          Text(
                                            '-${formatter.format(dailyExpense)}',
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Transactions
                                  ...dayTransactions.asMap().entries.map((entry) {
                                    final transactionIndex = entry.key;
                                    final transaction = entry.value;

                                    final uniqueKey = 'transaction_${transaction.id}_${dateIndex}_$transactionIndex';

                                    return _buildTransactionItem(
                                      transaction,
                                      formatter,
                                      uniqueKey,
                                    );
                                  }),

                                  const SizedBox(height: 10),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      // Single Floating Action Button for adding transactions
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTransactionTypeDialog(),
        backgroundColor: const Color(0xFF4DB6AC),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // Show dialog to choose transaction type
  void _showTransactionTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Transaksi'),
        content: const Text('Pilih jenis transaksi:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showAddTransactionDialog(isExpense: false);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: Colors.green),
                SizedBox(width: 5),
                Text('Pemasukan', style: TextStyle(color: Colors.green)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showAddTransactionDialog(isExpense: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.remove, color: Colors.white),
                SizedBox(width: 5),
                Text('Pengeluaran', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
    Color textColor = Colors.black87,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top row with icon and edit indicator
            Row(
              children: [
                Icon(icon, color: textColor.withOpacity(0.7), size: 18),
                if (onTap != null) ...[
                  const Spacer(),
                  Icon(Icons.edit, color: textColor.withOpacity(0.5), size: 14),
                ],
              ],
            ),

            // Amount - main content
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    amount,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ),

            // Bottom section with title and subtitle
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9,
                      color: textColor.withOpacity(0.6),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4DB6AC) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(TransactionModel transaction, NumberFormat formatter, String uniqueKey) {
    final icon = transaction.isExpense
        ? expenseCategories[transaction.category] ?? Icons.category
        : incomeCategories[transaction.category] ?? Icons.attach_money;

    return Container(
      key: ValueKey(uniqueKey),
      margin: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key('dismissible_$uniqueKey'),
        direction: DismissDirection.endToStart,
        background: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(15),
          ),
          alignment: Alignment.centerRight,
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Hapus Transaksi'),
              content: Text('Yakin ingin menghapus "${transaction.title}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Hapus', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ) ?? false;
        },
        onDismissed: (direction) {
          transaction.delete();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${transaction.title} berhasil dihapus'),
              action: SnackBarAction(
                label: 'UNDO',
                onPressed: () {
                  transactionBox.add(transaction);
                },
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(15),
          ),
          child: InkWell(
            onTap: () => _showAddTransactionDialog(
              isExpense: transaction.isExpense,
              editTransaction: transaction,
            ),
            onLongPress: () => _deleteTransaction(transaction),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: transaction.isExpense ? Colors.red[50] : Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: transaction.isExpense ? Colors.red : Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              transaction.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                      if (transaction.notes != null && transaction.notes!.isNotEmpty)
                        Text(
                          transaction.notes!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${transaction.isExpense ? '-' : '+'}${formatter.format(transaction.amount)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: transaction.isExpense ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}