import 'package:flutter_test/flutter_test.dart';
import 'package:savage_bot/providers/savage_bot_provider.dart';
import 'package:savage_bot/services/hybrid_nlp_service.dart';
import 'package:savage_bot/services/vietqr_service.dart';

void main() {
  group('HybridNlpService.parseNaturalInput', () {
    test('parses shorthand Vietnamese currency suffixes and number words', () {
      final bunBo = HybridNlpService.parseNaturalInput('bún bò huế 45k');
      expect(bunBo, isNotNull);
      expect(bunBo!.amountVnd, 45000);
      expect(bunBo.category, ExpenseCategory.foodAndDrink);

      final bunBoWords =
          HybridNlpService.parseNaturalInput('bún bò bốn mươi lăm nghìn');
      expect(bunBoWords, isNotNull);
      expect(bunBoWords!.amountVnd, 45000);

      final traSuaWords =
          HybridNlpService.parseNaturalInput('trà sữa năm mươi lăm nghìn');
      expect(traSuaWords, isNotNull);
      expect(traSuaWords!.amountVnd, 55000);
      expect(traSuaWords.category, ExpenseCategory.bobaAndCafe);

      final traSuaCa = HybridNlpService.parseNaturalInput('trà sữa 55 ca');
      expect(traSuaCa, isNotNull);
      expect(traSuaCa!.amountVnd, 55000);
      expect(traSuaCa.category, ExpenseCategory.bobaAndCafe);
    });

    test('parses spoken slang, mixed units, and formatted amounts', () {
      final tienPhong =
          HybridNlpService.parseNaturalInput('tiền phòng một triệu hai');
      expect(tienPhong, isNotNull);
      expect(tienPhong!.amountVnd, 1200000);
      expect(tienPhong.category, ExpenseCategory.dormAndUtilities);

      final guiXe = HybridNlpService.parseNaturalInput('gửi xe năm chục');
      expect(guiXe, isNotNull);
      expect(guiXe!.amountVnd, 50000);
      expect(guiXe.category, ExpenseCategory.transport);

      final tienNha =
          HybridNlpService.parseNaturalInput('tiền nhà 1.500.000đ');
      expect(tienNha, isNotNull);
      expect(tienNha!.amountVnd, 1500000);
      expect(tienNha.category, ExpenseCategory.dormAndUtilities);

      final cuRuoi = HybridNlpService.parseNaturalInput('tiền trọ 1 củ rưỡi');
      expect(cuRuoi, isNotNull);
      expect(cuRuoi!.amountVnd, 1500000);
      expect(cuRuoi.category, ExpenseCategory.dormAndUtilities);

      final xang = HybridNlpService.parseNaturalInput('xăng 2 lít rưỡi');
      expect(xang, isNotNull);
      expect(xang!.amountVnd, 250000);
      expect(xang.category, ExpenseCategory.transport);
    });

    test('classifies dorm utilities and ignores non-currency numbers like phòng 302',
        () {
      final nuocGiat = HybridNlpService.parseNaturalInput('nước giặt 120k');
      expect(nuocGiat, isNotNull);
      expect(nuocGiat!.amountVnd, 120000);
      expect(nuocGiat.category, ExpenseCategory.dormAndUtilities);

      final bento = HybridNlpService.parseNaturalInput('bento gà 45k');
      expect(bento, isNotNull);
      expect(bento!.amountVnd, 45000);

      final roomNumberAndPrice =
          HybridNlpService.parseNaturalInput('cơm trưa 35k phòng 302');
      expect(roomNumberAndPrice, isNotNull);
      expect(roomNumberAndPrice!.amountVnd, 35000);

      final roomOnly = HybridNlpService.parseNaturalInput('phòng 302');
      expect(roomOnly, isNull);
    });
  });

  group('VietQrService EMVCo NAPAS 247', () {
    test('computes standard CRC-16/CCITT-FALSE check vector', () {
      expect(VietQrService.crc16CcittFalse('123456789'), '29B1');
    });

    test('builds dynamic Tag 54, ASCII Tag 62 memo, and valid Tag 63 CRC', () {
      final memo = VietQrService.buildReconciliationMemo(
        groupName: 'Phòng 302',
        memberName: 'Tuất',
      );
      expect(memo, 'SB_PHONG302_TUAT');

      final payload = VietQrService.buildNapas247Payload(
        bankBin: '970422',
        accountNumber: '0988882026',
        amountVnd: 400000,
        memo: memo,
      );

      expect(payload.contains('5406400000'), isTrue);
      expect(payload.contains('SB_PHONG302_TUAT'), isTrue);
      expect(payload.length, greaterThan(10));

      final bodyWith6304 = payload.substring(0, payload.length - 4);
      final trailingCrc = payload.substring(payload.length - 4);
      expect(bodyWith6304.endsWith('6304'), isTrue);
      expect(trailingCrc, VietQrService.crc16CcittFalse(bodyWith6304));
    });
  });

  group('SavageBotNotifier financial & closed-loop guarantees', () {
    test('fresh user starts unboarded with zero demo data', () {
      final notifier = SavageBotNotifier(enablePersistence: false);
      expect(notifier.state.hasCompletedOnboarding, isFalse);
      expect(notifier.state.transactions, isEmpty);
      expect(notifier.state.splitItems, isEmpty);
      expect(notifier.state.tier1QueryCount, 0);
      expect(notifier.state.tier2QueryCount, 0);

      notifier.completeNewUserOnboarding(
        groupName: 'Ví Hùng',
        members: const ['Hùng'],
        monthlyBudget: 3000000,
        activePersona: PersonaMode.coach,
      );

      expect(notifier.state.hasCompletedOnboarding, isTrue);
      expect(notifier.state.groupName, 'Ví Hùng');
      expect(notifier.state.members, const ['Hùng']);
      expect(notifier.state.transactions, isEmpty);
      expect(notifier.state.splitItems, isEmpty);
      expect(notifier.state.dailySafeToSpend, 100000);
      expect(notifier.state.predictedRunwayDays, 30);
    });

    test('deducts full personal expense and exact 1/N share for split bills', () {
      final notifier =
          SavageBotNotifier(enablePersistence: false, startWithDemo: true);
      final initialDaily = notifier.state.dailySafeToSpend;
      final initialSplitCount = notifier.state.splitItems.length;

      final okPersonal = notifier.addExpenseFromInput('cơm 40k');
      expect(okPersonal, isTrue);
      expect(notifier.state.dailySafeToSpend, initialDaily - 40000);
      expect(notifier.state.splitItems.length, initialSplitCount);

      final okShared = notifier.addExpenseFromInput(
        'tiền nước 90k',
        isSharedRoomExpense: true,
      );
      expect(okShared, isTrue);
      expect(notifier.state.dailySafeToSpend, initialDaily - 40000 - 30000);
      expect(notifier.state.splitItems.length, initialSplitCount + 1);
      expect(notifier.state.splitItems.first.totalAmountVnd, 90000);
    });

    test('enforces idempotent per-member VietQR settlement', () async {
      final notifier =
          SavageBotNotifier(enablePersistence: false, startWithDemo: true);
      final initialDaily = notifier.state.dailySafeToSpend;
      final tuatShare = notifier.state.shareForRoommate('Tuất');

      expect(notifier.state.isMemberSettled('Tuất'), isFalse);

      notifier.selectRoommateForQr('Tuất');
      await notifier.triggerVietQrReconciliation(
        simulatedLatency: Duration.zero,
      );

      expect(notifier.state.isMemberSettled('Tuất'), isTrue);
      expect(notifier.state.dailySafeToSpend, initialDaily + tuatShare);

      notifier.selectRoommateForQr('Hưng');
      expect(notifier.state.isMemberSettled('Hưng'), isFalse);
      expect(notifier.state.isMemberSettled('Tuất'), isTrue);

      notifier.selectRoommateForQr('Tuất');
      await notifier.triggerVietQrReconciliation(
        simulatedLatency: Duration.zero,
      );
      expect(notifier.state.dailySafeToSpend, initialDaily + tuatShare);
    });

    test('OCR batch scan increments tier2QueryCount only', () {
      final notifier =
          SavageBotNotifier(enablePersistence: false, startWithDemo: true);
      final initialTier1 = notifier.state.tier1QueryCount;
      final initialTier2 = notifier.state.tier2QueryCount;
      final initialSplits = notifier.state.splitItems.length;

      notifier.addMultiItemReceiptScan(
        template: OcrReceiptTemplate.dormUtilities,
      );

      expect(notifier.state.tier1QueryCount, initialTier1);
      expect(notifier.state.tier2QueryCount, initialTier2 + 1);
      expect(notifier.state.splitItems.length, greaterThan(initialSplits));
    });
  });
}
