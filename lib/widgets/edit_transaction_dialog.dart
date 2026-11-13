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
  final titleController = TextEditingController(text: transaction.title);
  final amountController =
      TextEditingController(text: transaction.amountVnd.toString());
  ExpenseCategory selectedCategory = transaction.category;
  String selectedPayer = members.contains(transaction.payerName)
      ? transaction.payerName
      : (members.isNotEmpty ? members.first : transaction.payerName);

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final textPrimary = AppColors.textPrimary(isDark);
      final surface = AppColors.surface(isDark);

      return StatefulBuilder(
        builder: (ctx, setStateDialog) {
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
                    controller: titleController,
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
                    controller: amountController,
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
                    initialValue: selectedCategory,
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
                        setStateDialog(() => selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (members.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: members.map((m) {
                        final active = m == selectedPayer;
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
                            setStateDialog(() => selectedPayer = m);
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
                  onDelete();
                  Navigator.of(ctx).pop();
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
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () {
                  final parsedAmt = int.tryParse(amountController.text.trim());
                  final cleanTitle = titleController.text.trim();
                  if (cleanTitle.isEmpty ||
                      parsedAmt == null ||
                      parsedAmt <= 0) {
                    return;
                  }
                  HapticFeedback.mediumImpact();
                  onSave(
                    title: cleanTitle,
                    amountVnd: parsedAmt,
                    category: selectedCategory,
                    payerName: selectedPayer,
                  );
                  Navigator.of(ctx).pop();
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
        },
      );
    },
  );
  titleController.dispose();
  amountController.dispose();
}
