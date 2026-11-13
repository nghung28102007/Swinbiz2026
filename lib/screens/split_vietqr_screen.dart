import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/savage_bot_provider.dart';
import '../services/hybrid_nlp_service.dart';
import '../services/vietqr_service.dart';
import '../theme/app_tokens.dart';

class SplitVietQrScreen extends ConsumerStatefulWidget {
  const SplitVietQrScreen({super.key});

  @override
  ConsumerState<SplitVietQrScreen> createState() => _SplitVietQrScreenState();
}

class _SplitVietQrScreenState extends ConsumerState<SplitVietQrScreen> {
  final TextEditingController _customBillController = TextEditingController();

  @override
  void dispose() {
    _customBillController.dispose();
    super.dispose();
  }

  void _addNewRoomBill() {
    final parsed =
        HybridNlpService.parseNaturalInput(_customBillController.text);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.rose,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          content: const Text(
            'Nhập tên khoản chung + số tiền (VD: "Mua bình nước lọc 60k" hoặc "Tiền rác 90k")',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    ref.read(savageBotProvider.notifier).addCustomSplitItem(
          '${parsed.category.emoji} ${parsed.itemTitle}',
          parsed.amountVnd,
        );
    _customBillController.clear();
  }

  void _copyValue(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.emerald,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        content: Text(
          'Đã sao chép $label: $value',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _openQrZoomModal({
    required BuildContext context,
    required String napasPayload,
    required String activeRoommate,
    required int amountVnd,
    required String memo,
    required String bankName,
    required String accountNumber,
    required String treasurerName,
  }) {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 32,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'VietQR NAPAS 247 • $activeRoommate',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                QrImageView(
                  data: napasPayload,
                  version: QrVersions.auto,
                  size: 260,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  HybridNlpService.formatVnd(amountVnd),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.emeraldDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$bankName • $accountNumber • $treasurerName',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Nội dung CK: $memo',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.violetDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchVietQrDeepLink(
    BuildContext context,
    WidgetRef ref,
    int amountVnd,
    String bankBin,
    String accountNumber,
    String memo,
  ) async {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(savageBotProvider.notifier);

    final Uri deepLinkUri = Uri.parse(
      'https://dl.vietqr.io/pay?app=mb&ba=$accountNumber@$bankBin&am=$amountVnd&tn=$memo',
    );

    try {
      if (await canLaunchUrl(deepLinkUri)) {
        await launchUrl(deepLinkUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Runs simulated webhook listener seamlessly on web/desktop/emulator
    }

    await notifier.triggerVietQrReconciliation();
  }

  @override
  Widget build(BuildContext context) {
    final botState = ref.watch(savageBotProvider);
    final notifier = ref.read(savageBotProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color cardSurface = AppColors.surface(isDark);
    final Color secondarySurface = AppColors.secondarySurface(isDark);
    final Color borderColor = AppColors.border(isDark);
    final Color textPrimary = AppColors.textPrimary(isDark);
    final Color textSecondary = AppColors.textSecondary(isDark);

    final List<String> members = botState.members;
    final String activeRoommate = members.contains(botState.selectedRoommateForQr)
        ? botState.selectedRoommateForQr
        : members.first;
    final int roommateOwedAmount = botState.shareForRoommate(activeRoommate);
    final bool isSelectedSettled = botState.isMemberSettled(activeRoommate);
    final String memo = VietQrService.buildReconciliationMemo(
      groupName: botState.groupName,
      memberName: activeRoommate,
    );
    final String napasPayload = VietQrService.buildNapas247Payload(
      bankBin: botState.bankBin,
      accountNumber: botState.bankAccount,
      amountVnd: roommateOwedAmount,
      memo: memo,
    );
    final String bankName = VietQrService.bankNameForBin(botState.bankBin);

    Widget buildMemberCard(String member) {
      final share = botState.shareForRoommate(member);
      final isSelected = activeRoommate == member;
      final isMemberDone = botState.isMemberSettled(member);
      final isTreasurer = member == botState.treasurerName;

      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          notifier.selectRoommateForQr(member);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 10,
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [AppColors.violet, AppColors.violetDark],
                  )
                : null,
            color: isSelected ? null : cardSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? AppColors.violetLight
                  : (isMemberDone ? AppColors.emerald : borderColor),
              width: isMemberDone && !isSelected ? 1.3 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isTreasurer ? '👑 $member' : member,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                HybridNlpService.formatCompactVnd(share),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isMemberDone
                      ? AppColors.emerald.withValues(alpha: isSelected ? 0.28 : 0.16)
                      : AppColors.amber.withValues(alpha: isSelected ? 0.25 : 0.14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  isMemberDone ? '✓ Đã trả' : 'Chờ trả',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? Colors.white
                        : (isMemberDone ? AppColors.emerald : AppColors.amber),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. TOP DYNAMIC ROOMMATE SUMMARY STRIP
            if (members.length <= 3)
              Row(
                children: members.map((member) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: buildMemberCard(member),
                    ),
                  );
                }).toList(),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: members.map((member) {
                    return Container(
                      width: 116,
                      margin: const EdgeInsets.only(right: 8),
                      child: buildMemberCard(member),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 12),

            // 2. SCROLLABLE WORKSPACE: ADD BILL + SPLIT MATRIX + VIETQR CARD
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardSurface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '➕ Khoản Chung ${botState.groupName}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tổng quỹ: ${HybridNlpService.formatVnd(botState.totalSplitPoolVnd)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.emerald,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customBillController,
                                onSubmitted: (_) => _addNewRoomBill(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Gõ khoản chung: "nước giặt 120k", "bình nước 60k"...',
                                  hintStyle: TextStyle(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  filled: true,
                                  fillColor: secondarySurface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _addNewRoomBill,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.emerald,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Thêm',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Interactive Split Items List (Overflow-safe with Wrap)
                        ...botState.splitItems.map((item) {
                          final perPerson = item.assignedRoommates.isEmpty
                              ? 0
                              : (item.totalAmountVnd /
                                      item.assignedRoommates.length)
                                  .round();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: secondarySurface,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        HybridNlpService.formatVnd(
                                          item.totalAmountVnd,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.emerald,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          notifier.deleteSplitItem(item.id);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 15,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      ...members.map((name) {
                                        final isAssigned = item
                                            .assignedRoommates
                                            .contains(name);
                                        return GestureDetector(
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            notifier.toggleRoommateOnSplitItem(
                                              item.id,
                                              name,
                                            );
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 160,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isAssigned
                                                  ? AppColors.violet
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                              border: Border.all(
                                                color: isAssigned
                                                    ? AppColors.violet
                                                    : textSecondary.withValues(
                                                        alpha: 0.4,
                                                      ),
                                              ),
                                            ),
                                            child: Text(
                                              isAssigned ? '✓ $name' : name,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: isAssigned
                                                    ? Colors.white
                                                    : textSecondary,
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 4),
                                        child: Text(
                                          '${HybridNlpService.formatCompactVnd(perPerson)}/người',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Dynamic EMVCo NAPAS 247 VietQR Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardSurface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(
                        color: isSelectedSettled
                            ? AppColors.emerald
                            : AppColors.violet.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mã VietQR Của $activeRoommate',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: textPrimary,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '$bankName • ${botState.bankAccount} • ${botState.treasurerName}',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () => _copyValue(
                                          'Số tài khoản',
                                          botState.bankAccount,
                                        ),
                                        child: const Icon(
                                          Icons.copy_rounded,
                                          size: 13,
                                          color: AppColors.emerald,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isSelectedSettled
                                    ? AppColors.emerald.withValues(alpha: 0.16)
                                    : AppColors.amber.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                isSelectedSettled
                                    ? 'Đã gạch nợ ✓'
                                    : (botState.isWebhookListening
                                        ? 'Đang đối soát...'
                                        : 'Chờ trả'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isSelectedSettled
                                      ? AppColors.emerald
                                      : AppColors.amber,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            // Tap QR to zoom 260x260 for stage/distance scanning
                            GestureDetector(
                              onTap: () => _openQrZoomModal(
                                context: context,
                                napasPayload: napasPayload,
                                activeRoommate: activeRoommate,
                                amountVnd: roommateOwedAmount,
                                memo: memo,
                                bankName: bankName,
                                accountNumber: botState.bankAccount,
                                treasurerName: botState.treasurerName,
                              ),
                              child: Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: QrImageView(
                                      data: napasPayload,
                                      version: QrVersions.auto,
                                      size: 124,
                                    ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    bottom: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.violet
                                            .withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.zoom_out_map_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Số tiền cần đóng:',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _copyValue(
                                      'Số tiền',
                                      roommateOwedAmount.toString(),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            HybridNlpService.formatVnd(
                                              roommateOwedAmount,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Icon(
                                          Icons.copy_rounded,
                                          size: 14,
                                          color: textSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => _copyValue('Nội dung CK', memo),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: secondarySurface,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.tag_rounded,
                                            size: 13,
                                            color: AppColors.violet,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              memo,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                color: AppColors.violet,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          const Icon(
                                            Icons.copy_rounded,
                                            size: 12,
                                            color: AppColors.violet,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Chạm mã QR để phóng to khi quét',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 4. BOTTOM THUMB-ZONE 1-TOUCH BANK DEEP-LINK TRIGGER
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: botState.isWebhookListening
                    ? null
                    : () => _launchVietQrDeepLink(
                          context,
                          ref,
                          roommateOwedAmount,
                          botState.bankBin,
                          botState.bankAccount,
                          memo,
                        ),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isSelectedSettled ? AppColors.emerald : AppColors.violet,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: Icon(
                  isSelectedSettled
                      ? Icons.check_circle_rounded
                      : Icons.contactless_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                label: Text(
                  botState.isWebhookListening
                      ? 'Webhook đang lắng nghe giao dịch...'
                      : (isSelectedSettled
                          ? '$activeRoommate đã gạch nợ thành công'
                          : 'Mở App Ngân Hàng • ${HybridNlpService.formatVnd(roommateOwedAmount)}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
