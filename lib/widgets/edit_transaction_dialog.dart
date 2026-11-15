import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/hybrid_nlp_service.dart';
import '../theme/app_tokens.dart';

/// Opens a clean modal dialog to edit or delete a recorded expense transaction.
Future<void> showEditTransactionDialog({
  required BuildContext context,
  required ExpenseTransaction transaction,
  required List<String> members,
  required void Function({
    required String title,
    required int amountVnd,
    required ExpenseCategory category,
    required String payerName,
  }) onSave,
  required VoidCallback onDelete,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _EditTransactionDialog(
      transaction: transaction,
      members: members,
      onSave: onSave,
      onDelete: onDelete,
    ),
  );
}

class _EditTransactionDialog extends StatefulWidget {
  final ExpenseTransaction transaction;
  final List<String> members;
  final void Function({
    required String title,
    required int amountVnd,
    required ExpenseCategory category,
    required String payerName,
  }) onSave;
  final VoidCallback onDelete;

  const _EditTransactionDialog({
    required this.transaction,
    required this.members,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_EditTransactionDialog> createState() => _EditTransactionDialogState();
}

class _EditTransactionDialogState extends State<_EditTransactionDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late ExpenseCategory _selectedCategory;
  late String _selectedPayer;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.transaction.title);
    _amountController = TextEditingController(
      text: widget.transaction.amountVnd.toString(),
    );
    _selectedCategory = widget.transaction.category;
    _selectedPayer = widget.members.contains(widget.transaction.payerName)
        ? widget.transaction.payerName
        : (widget.members.isNotEmpty
            ? widget.members.first
            : widget.transaction.payerName);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(isDark);
    final surface = AppColors.surface(isDark);

    return AlertDialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      title: Text(
        'Chỉnh Sửa Giao Dịch',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Nội dung chi tiêu',
                filled: true,
                fillColor: AppColors.secondarySurface(isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Số tiền (VNĐ)',
                filled: true,
                fillColor: AppColors.secondarySurface(isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<ExpenseCategory>(
              initialValue: _selectedCategory,
              isExpanded: true,
              dropdownColor: surface,
              decoration: InputDecoration(
                labelText: 'Danh mục',
                filled: true,
                fillColor: AppColors.secondarySurface(isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide.none,
                ),
              ),
              items: ExpenseCategory.values.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(
                    '${cat.emoji} ${cat.labelVi}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCategory = val);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            if (widget.members.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.members.map((m) {
                  final active = m == _selectedPayer;
                  return ChoiceChip(
                    label: Text(m),
                    selected: active,
                    selectedColor: AppColors.violet,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : textPrimary,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedPayer = m);
                    },
                  );
                }).toList(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            HapticFeedback.mediumImpact();
            widget.onDelete();
            Navigator.of(context).pop();
          },
          icon: const Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: AppColors.rose,
          ),
          label: const Text(
            'Xóa',
            style: TextStyle(
              color: AppColors.rose,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            final parsedAmt = int.tryParse(_amountController.text.trim());
            final cleanTitle = _titleController.text.trim();
            if (cleanTitle.isEmpty || parsedAmt == null || parsedAmt <= 0) {
              return;
            }
            HapticFeedback.mediumImpact();
            widget.onSave(
              title: cleanTitle,
              amountVnd: parsedAmt,
              category: _selectedCategory,
              payerName: _selectedPayer,
            );
            Navigator.of(context).pop();
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.emerald,
          ),
          child: const Text(
            'Lưu',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
