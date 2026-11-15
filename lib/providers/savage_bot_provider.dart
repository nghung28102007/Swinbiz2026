import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/hybrid_nlp_service.dart';
import '../services/vietqr_service.dart';

enum OcrReceiptTemplate {
  circleK,
  pheLa,
  dormUtilities,
}

extension OcrReceiptTemplateExt on OcrReceiptTemplate {
  String get label {
    switch (this) {
      case OcrReceiptTemplate.circleK:
        return 'Circle K Đêm';
      case OcrReceiptTemplate.pheLa:
        return 'Phê La Nhóm';
      case OcrReceiptTemplate.dormUtilities:
        return 'Điện Nước Trọ';
    }
  }

  String get merchantHeader {
    switch (this) {
      case OcrReceiptTemplate.circleK:
        return 'CIRCLE K VIETNAM • CAU GIAY';
      case OcrReceiptTemplate.pheLa:
        return 'PHE LA COFFEE & TEA • XUAN THUY';
      case OcrReceiptTemplate.dormUtilities:
        return 'HOA DON DICH VU PHONG TRO';
    }
  }

  String get timeLabel {
    switch (this) {
      case OcrReceiptTemplate.circleK:
        return '23:42 PM';
      case OcrReceiptTemplate.pheLa:
        return '15:18 PM';
      case OcrReceiptTemplate.dormUtilities:
        return '09:05 AM';
    }
  }

  List<({String title, int amount, ExpenseCategory category})> get items {
    switch (this) {
      case OcrReceiptTemplate.circleK:
        return const [
          (
            title: 'Mì trộn Indomie trứng lòng đào',
            amount: 28000,
            category: ExpenseCategory.foodAndDrink,
          ),
          (
            title: 'Nước tăng lực Monster Ultra',
            amount: 32000,
            category: ExpenseCategory.bobaAndCafe,
          ),
          (
            title: 'Xúc xích phô mai CP',
            amount: 18000,
            category: ExpenseCategory.foodAndDrink,
          ),
        ];
      case OcrReceiptTemplate.pheLa:
        return const [
          (
            title: 'Ô Long Sữa Phê La (L)',
            amount: 55000,
            category: ExpenseCategory.bobaAndCafe,
          ),
          (
            title: 'Trà Sữa Gạo Rang Đặc Biệt',
            amount: 58000,
            category: ExpenseCategory.bobaAndCafe,
          ),
          (
            title: 'Topping Trân Châu Ô Long',
            amount: 12000,
            category: ExpenseCategory.bobaAndCafe,
          ),
        ];
      case OcrReceiptTemplate.dormUtilities:
        return const [
          (
            title: 'Tiền điện EVN tháng này',
            amount: 420000,
            category: ExpenseCategory.dormAndUtilities,
          ),
          (
            title: 'Tiền nước sinh hoạt',
            amount: 90000,
            category: ExpenseCategory.dormAndUtilities,
          ),
          (
            title: 'Phí rác & vệ sinh chung',
            amount: 40000,
            category: ExpenseCategory.dormAndUtilities,
          ),
        ];
    }
  }

  int get totalVnd => items.fold(0, (sum, item) => sum + item.amount);
}

class RoommateSplitItem {
  final String id;
  final String title;
  final int totalAmountVnd;
  final List<String> assignedRoommates;

  const RoommateSplitItem({
    required this.id,
    required this.title,
    required this.totalAmountVnd,
    required this.assignedRoommates,
  });

  RoommateSplitItem copyWith({
    String? id,
    String? title,
    int? totalAmountVnd,
    List<String>? assignedRoommates,
  }) {
    return RoommateSplitItem(
      id: id ?? this.id,
      title: title ?? this.title,
      totalAmountVnd: totalAmountVnd ?? this.totalAmountVnd,
      assignedRoommates: assignedRoommates ?? this.assignedRoommates,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'totalAmountVnd': totalAmountVnd,
      'assignedRoommates': assignedRoommates,
    };
  }

  factory RoommateSplitItem.fromJson(Map<String, dynamic> json) {
    return RoommateSplitItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      totalAmountVnd: (json['totalAmountVnd'] as num?)?.toInt() ?? 0,
      assignedRoommates: (json['assignedRoommates'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class SavageBotState {
  final String groupName;
  final List<String> members;
  final String treasurerName;
  final String bankBin;
  final String bankAccount;
  final int monthlyBudget;
  final int dailyBaseAllowance;
  final int dailySafeToSpend;
  final int predictedRunwayDays;
  final int noBobaStreakDays;
  final PersonaMode activePersona;
  final String activePayer;
  final List<ExpenseTransaction> transactions;
  final String latestSpeechBubble;
  final List<RoommateSplitItem> splitItems;
  final String selectedRoommateForQr;
  final Map<String, bool> settledByMember;
  final bool isWebhookListening;
  final int tier1QueryCount;
  final int tier2QueryCount;
  final double simulatedMau;
  final bool isDarkMode;
  final bool hasCompletedOnboarding;

  const SavageBotState({
    required this.groupName,
    required this.members,
    required this.treasurerName,
    required this.bankBin,
    required this.bankAccount,
    required this.monthlyBudget,
    required this.dailyBaseAllowance,
    required this.dailySafeToSpend,
    required this.predictedRunwayDays,
    required this.noBobaStreakDays,
    required this.activePersona,
    required this.activePayer,
    required this.transactions,
    required this.latestSpeechBubble,
    required this.splitItems,
    required this.selectedRoommateForQr,
    required this.settledByMember,
    required this.isWebhookListening,
    required this.tier1QueryCount,
    required this.tier2QueryCount,
    required this.simulatedMau,
    required this.isDarkMode,
    this.hasCompletedOnboarding = true,
  });

  bool isMemberSettled(String member) => settledByMember[member] ?? false;

  bool get isVietQrSettled => isMemberSettled(selectedRoommateForQr);

  int get totalSpentThisMonth =>
      transactions.fold(0, (sum, item) => sum + item.amountVnd);

  int get remainingMonthlyBudget =>
      (monthlyBudget - totalSpentThisMonth).clamp(0, monthlyBudget);

  double get monthlyBudgetUsedRatio => monthlyBudget <= 0
      ? 0.0
      : (totalSpentThisMonth / monthlyBudget).clamp(0.0, 1.0);

  double get tier1RatioPercent {
    final total = tier1QueryCount + tier2QueryCount;
    if (total == 0) return 100.0;
    return (tier1QueryCount / total) * 100.0;
  }

  Map<ExpenseCategory, int> get categoryTotals {
    final Map<ExpenseCategory, int> map = {
      for (final c in ExpenseCategory.values) c: 0,
    };
    for (final tx in transactions) {
      map[tx.category] = (map[tx.category] ?? 0) + tx.amountVnd;
    }
    return map;
  }

  int shareForRoommate(String roommateName) {
    int totalShare = 0;
    for (final item in splitItems) {
      if (item.assignedRoommates.contains(roommateName) &&
          item.assignedRoommates.isNotEmpty) {
        totalShare +=
            (item.totalAmountVnd / item.assignedRoommates.length).round();
      }
    }
    return totalShare;
  }

  int get totalSplitPoolVnd =>
      splitItems.fold(0, (sum, item) => sum + item.totalAmountVnd);

  int get averageTransactionVnd => transactions.isEmpty
      ? 0
      : (totalSpentThisMonth / transactions.length).round();

  ExpenseCategory? get topSpendingCategory {
    if (transactions.isEmpty) return null;
    final totals = categoryTotals;
    ExpenseCategory? topCat;
    int maxVal = 0;
    for (final entry in totals.entries) {
      if (entry.value > maxVal) {
        maxVal = entry.value;
        topCat = entry.key;
      }
    }
    return topCat;
  }

  int get unsettledRoommateTotalVnd {
    int sum = 0;
    for (final m in members) {
      if (!isMemberSettled(m)) {
        sum += shareForRoommate(m);
      }
    }
    return sum;
  }

  Map<String, int> get payerTotals {
    final Map<String, int> map = {
      for (final m in members) m: 0,
    };
    for (final tx in transactions) {
      map[tx.payerName] = (map[tx.payerName] ?? 0) + tx.amountVnd;
    }
    return map;
  }

  SavageBotState copyWith({
    String? groupName,
    List<String>? members,
    String? treasurerName,
    String? bankBin,
    String? bankAccount,
    int? monthlyBudget,
    int? dailyBaseAllowance,
    int? dailySafeToSpend,
    int? predictedRunwayDays,
    int? noBobaStreakDays,
    PersonaMode? activePersona,
    String? activePayer,
    List<ExpenseTransaction>? transactions,
    String? latestSpeechBubble,
    List<RoommateSplitItem>? splitItems,
    String? selectedRoommateForQr,
    Map<String, bool>? settledByMember,
    bool? isWebhookListening,
    int? tier1QueryCount,
    int? tier2QueryCount,
    double? simulatedMau,
    bool? isDarkMode,
    bool? hasCompletedOnboarding,
  }) {
    return SavageBotState(
      groupName: groupName ?? this.groupName,
      members: members ?? this.members,
      treasurerName: treasurerName ?? this.treasurerName,
      bankBin: bankBin ?? this.bankBin,
      bankAccount: bankAccount ?? this.bankAccount,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      dailyBaseAllowance: dailyBaseAllowance ?? this.dailyBaseAllowance,
      dailySafeToSpend: dailySafeToSpend ?? this.dailySafeToSpend,
      predictedRunwayDays: predictedRunwayDays ?? this.predictedRunwayDays,
      noBobaStreakDays: noBobaStreakDays ?? this.noBobaStreakDays,
      activePersona: activePersona ?? this.activePersona,
      activePayer: activePayer ?? this.activePayer,
      transactions: transactions ?? this.transactions,
      latestSpeechBubble: latestSpeechBubble ?? this.latestSpeechBubble,
      splitItems: splitItems ?? this.splitItems,
      selectedRoommateForQr:
          selectedRoommateForQr ?? this.selectedRoommateForQr,
      settledByMember: settledByMember ?? this.settledByMember,
      isWebhookListening: isWebhookListening ?? this.isWebhookListening,
      tier1QueryCount: tier1QueryCount ?? this.tier1QueryCount,
      tier2QueryCount: tier2QueryCount ?? this.tier2QueryCount,
      simulatedMau: simulatedMau ?? this.simulatedMau,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupName': groupName,
      'members': members,
      'treasurerName': treasurerName,
      'bankBin': bankBin,
      'bankAccount': bankAccount,
      'monthlyBudget': monthlyBudget,
      'dailyBaseAllowance': dailyBaseAllowance,
      'dailySafeToSpend': dailySafeToSpend,
      'predictedRunwayDays': predictedRunwayDays,
      'noBobaStreakDays': noBobaStreakDays,
      'activePersona': activePersona.name,
      'activePayer': activePayer,
      'transactions': transactions.map((e) => e.toJson()).toList(),
      'latestSpeechBubble': latestSpeechBubble,
      'splitItems': splitItems.map((e) => e.toJson()).toList(),
      'selectedRoommateForQr': selectedRoommateForQr,
      'settledByMember': settledByMember,
      'tier1QueryCount': tier1QueryCount,
      'tier2QueryCount': tier2QueryCount,
      'simulatedMau': simulatedMau,
      'isDarkMode': isDarkMode,
      'hasCompletedOnboarding': hasCompletedOnboarding,
    };
  }

  factory SavageBotState.fromJson(Map<String, dynamic> json) {
    final parsedMembers = (json['members'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final members =
        parsedMembers.isEmpty ? const ['Bạn'] : parsedMembers;

    final settledRaw = json['settledByMember'] as Map<String, dynamic>? ?? {};
    final Map<String, bool> settled = {
      for (final entry in settledRaw.entries)
        entry.key: entry.value == true,
    };

    final String activePayerRaw = json['activePayer'] as String? ?? members.first;
    final String selectedQrRaw =
        json['selectedRoommateForQr'] as String? ?? members.last;
    final String treasurerRaw =
        json['treasurerName'] as String? ?? members.first;

    return SavageBotState(
      groupName: json['groupName'] as String? ?? 'Ví của tôi',
      members: members,
      treasurerName:
          members.contains(treasurerRaw) ? treasurerRaw : members.first,
      bankBin: json['bankBin'] as String? ?? '970422',
      bankAccount: json['bankAccount'] as String? ?? '0988882026',
      monthlyBudget: (json['monthlyBudget'] as num?)?.toInt() ?? 4000000,
      dailyBaseAllowance: (json['dailyBaseAllowance'] as num?)?.toInt() ?? 160000,
      dailySafeToSpend: (json['dailySafeToSpend'] as num?)?.toInt() ?? 160000,
      predictedRunwayDays: (json['predictedRunwayDays'] as num?)?.toInt() ?? 30,
      noBobaStreakDays: (json['noBobaStreakDays'] as num?)?.toInt() ?? 0,
      activePersona: PersonaMode.values.firstWhere(
        (m) => m.name == json['activePersona'],
        orElse: () => PersonaMode.savage,
      ),
      activePayer:
          members.contains(activePayerRaw) ? activePayerRaw : members.first,
      transactions: (json['transactions'] as List<dynamic>? ?? [])
          .map((e) => ExpenseTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      latestSpeechBubble: json['latestSpeechBubble'] as String? ?? '',
      splitItems: (json['splitItems'] as List<dynamic>? ?? [])
          .map((e) => RoommateSplitItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      selectedRoommateForQr:
          members.contains(selectedQrRaw) ? selectedQrRaw : members.last,
      settledByMember: settled,
      isWebhookListening: false,
      tier1QueryCount: (json['tier1QueryCount'] as num?)?.toInt() ?? 0,
      tier2QueryCount: (json['tier2QueryCount'] as num?)?.toInt() ?? 0,
      simulatedMau: (json['simulatedMau'] as num?)?.toDouble() ?? 25000,
      isDarkMode: json['isDarkMode'] as bool? ?? true,
      hasCompletedOnboarding: json['hasCompletedOnboarding'] as bool? ?? true,
    );
  }
}

class SavageBotNotifier extends StateNotifier<SavageBotState> {
  static const String _storageKey = 'savage_bot_state_v3';
  final bool enablePersistence;

  SavageBotNotifier({
    this.enablePersistence = true,
    bool startWithDemo = false,
  }) : super(
          startWithDemo ? _buildDemoPresetState() : _buildFreshUserState(),
        ) {
    if (enablePersistence) {
      _loadPersistedState();
    }
  }

  static SavageBotState _buildFreshUserState({bool isDarkMode = true}) {
    return SavageBotState(
      groupName: 'Ví của tôi',
      members: const ['Bạn'],
      treasurerName: 'Bạn',
      bankBin: '970422',
      bankAccount: '0988882026',
      monthlyBudget: 4500000,
      dailyBaseAllowance: 150000,
      dailySafeToSpend: 150000,
      predictedRunwayDays: 30,
      noBobaStreakDays: 0,
      activePersona: PersonaMode.savage,
      activePayer: 'Bạn',
      transactions: const [],
      latestSpeechBubble:
          'Ví trắng 100%! Nhập khoản chi đầu tiên (VD: "bún bò 45k") hoặc bấm Mic để SavageBot chấm điểm nhé! 🔥',
      splitItems: const [],
      selectedRoommateForQr: 'Bạn',
      settledByMember: const {},
      isWebhookListening: false,
      tier1QueryCount: 0,
      tier2QueryCount: 0,
      simulatedMau: 25000,
      isDarkMode: isDarkMode,
      hasCompletedOnboarding: false,
    );
  }

  static SavageBotState _buildDemoPresetState() {
    const String defaultGroup = 'Phòng 302';
    const List<String> defaultMembers = ['Duy', 'Tuất', 'Hưng'];
    const int initialMonthlyBudget = 4500000;
    const int dailyBase = 180000;

    final List<ExpenseTransaction> preloaded = [
      ExpenseTransaction(
        id: 'tx-duy-1',
        rawInput: 'cơm tấm sườn bì chả 35k',
        title: 'Cơm tấm sườn bì chả',
        amountVnd: 35000,
        category: ExpenseCategory.foodAndDrink,
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        payerName: 'Duy',
        routeTier: NlpRouteTier.tier1LocalRegex,
        latencyMs: 1.1,
        savageRoast:
            'Duy làm đĩa cơm sườn 35k là chuẩn bài sinh viên gương mẫu rồi, đừng tráng miệng thêm ly trà sữa 60k là được! 🍛👏',
        coachAdvice:
            'Bữa trưa 35.000đ của Duy nằm gọn trong khung an toàn. Giữ nhịp này giúp bạn dư 450.000đ cuối tháng! 🌱',
      ),
      ExpenseTransaction(
        id: 'tx-tuat-2',
        rawInput: 'trà sữa phê la ô long 55k',
        title: 'Trà sữa Phê La Ô Long',
        amountVnd: 55000,
        category: ExpenseCategory.bobaAndCafe,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        payerName: 'Tuất',
        routeTier: NlpRouteTier.tier1LocalRegex,
        latencyMs: 1.3,
        savageRoast:
            'Tuất lại cúng 55k cho Phê La! Ly thứ 4 trong tuần rồi đó chiến thần đường huyết, cuối tháng ăn mì Hảo Hảo đừng kêu cứu! 🧋💀',
        coachAdvice:
            'Tuất vừa chi 55.000đ cho đồ uống. Gợi ý: Tự pha trà túi lọc 2 buổi/tuần giúp tiết kiệm ngay 110.000đ! ✨',
      ),
      ExpenseTransaction(
        id: 'tx-hung-3',
        rawInput: 'tiền điện & wifi phòng 302 350k',
        title: 'Tiền điện & Wifi Phòng 302',
        amountVnd: 350000,
        category: ExpenseCategory.dormAndUtilities,
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
        payerName: 'Hưng',
        routeTier: NlpRouteTier.tier1LocalRegex,
        latencyMs: 1.5,
        isSettled: false,
        savageRoast:
            'Bay nhẹ 350k tiền điện Wifi! Mấy anh em bật điều hòa 18 độ cày rank xuyên đêm cho cố vào! ⚡💸',
        coachAdvice:
            'Khoản chi chung 350.000đ của Phòng 302 đã ghi nhận. Hãy qua tab "Chia tiền QR" để gạch nợ tự động cho các thành viên. 🤝',
      ),
    ];

    const List<RoommateSplitItem> defaultSplitItems = [
      RoommateSplitItem(
        id: 'split-1',
        title: '⚡ Tiền điện & Nước Phòng 302',
        totalAmountVnd: 660000,
        assignedRoommates: ['Duy', 'Tuất', 'Hưng'],
      ),
      RoommateSplitItem(
        id: 'split-2',
        title: '🌐 Cáp quang Wifi Viettel Mesh',
        totalAmountVnd: 240000,
        assignedRoommates: ['Duy', 'Tuất', 'Hưng'],
      ),
      RoommateSplitItem(
        id: 'split-3',
        title: '🍲 Lẩu bò tự sôi đêm chạy deadline',
        totalAmountVnd: 300000,
        assignedRoommates: ['Duy', 'Tuất'],
      ),
    ];

    const int spentToday = 35000 + 55000;
    final int safeToday = (dailyBase - spentToday).clamp(0, dailyBase);
    final int totalSpent = preloaded.fold(0, (s, e) => s + e.amountVnd);
    final int remainingMonthly = initialMonthlyBudget - totalSpent;
    final int runwayDays = (remainingMonthly / dailyBase).floor().clamp(1, 30);

    return SavageBotState(
      groupName: defaultGroup,
      members: defaultMembers,
      treasurerName: 'Duy',
      bankBin: '970422',
      bankAccount: '0988882026',
      monthlyBudget: initialMonthlyBudget,
      dailyBaseAllowance: dailyBase,
      dailySafeToSpend: safeToday,
      predictedRunwayDays: runwayDays,
      noBobaStreakDays: 5,
      activePersona: PersonaMode.savage,
      activePayer: 'Duy',
      transactions: preloaded,
      latestSpeechBubble: preloaded.last.savageRoast,
      splitItems: defaultSplitItems,
      selectedRoommateForQr: 'Tuất',
      settledByMember: const {},
      isWebhookListening: false,
      tier1QueryCount: 19,
      tier2QueryCount: 6,
      simulatedMau: 25000,
      isDarkMode: true,
    );
  }

  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      state = SavageBotState.fromJson(decoded);
    } catch (_) {
      // Ignore corrupt cache and keep default initial state
    }
  }

  Future<void> _persistState() async {
    if (!enablePersistence) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(state.toJson()));
    } catch (_) {
      // Ignore persistence failures on restricted sandboxes
    }
  }

  void toggleThemeMode() {
    state = state.copyWith(isDarkMode: !state.isDarkMode);
    _persistState();
  }

  void setActivePayer(String payer) {
    state = state.copyWith(activePayer: payer);
    _persistState();
  }

  void setPersona(PersonaMode mode) {
    final latestTx =
        state.transactions.isNotEmpty ? state.transactions.last : null;
    String updatedBubble = state.latestSpeechBubble;
    if (latestTx != null) {
      updatedBubble = mode == PersonaMode.savage
          ? latestTx.savageRoast
          : latestTx.coachAdvice;
    }
    state = state.copyWith(
      activePersona: mode,
      latestSpeechBubble: updatedBubble,
    );
    _persistState();
  }

  bool addExpenseFromInput(
    String rawInput, {
    String? customPayer,
    bool isSharedRoomExpense = false,
  }) {
    final parsed = HybridNlpService.parseNaturalInput(rawInput);
    if (parsed == null) return false;

    final String? detectedMember =
        HybridNlpService.detectMemberInQuery(rawInput, state.members);
    final String payer = customPayer ?? detectedMember ?? state.activePayer;
    final int memberCount = state.members.isEmpty ? 1 : state.members.length;
    final int personalImpactVnd = isSharedRoomExpense
        ? (parsed.amountVnd / memberCount).round()
        : parsed.amountVnd;

    final int updatedSafeToday =
        (state.dailySafeToSpend - personalImpactVnd)
            .clamp(0, state.dailyBaseAllowance);

    final int newTotalSpent = state.totalSpentThisMonth + parsed.amountVnd;
    final int remainingMonth =
        (state.monthlyBudget - newTotalSpent).clamp(0, state.monthlyBudget);
    final int baseAllowance =
        state.dailyBaseAllowance <= 0 ? 1 : state.dailyBaseAllowance;
    final int updatedRunwayDays =
        (remainingMonth / baseAllowance).floor().clamp(1, 30);

    final int updatedStreak = parsed.category == ExpenseCategory.bobaAndCafe
        ? 0
        : state.noBobaStreakDays;

    final String roastText = HybridNlpService.generatePersonaResponse(
      mode: PersonaMode.savage,
      itemTitle: parsed.itemTitle,
      amountVnd: parsed.amountVnd,
      category: parsed.category,
      remainingDailySafeVnd: updatedSafeToday,
      predictedRunwayDays: updatedRunwayDays,
      payerName: payer,
    );

    final String coachText = HybridNlpService.generatePersonaResponse(
      mode: PersonaMode.coach,
      itemTitle: parsed.itemTitle,
      amountVnd: parsed.amountVnd,
      category: parsed.category,
      remainingDailySafeVnd: updatedSafeToday,
      predictedRunwayDays: updatedRunwayDays,
      payerName: payer,
    );

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final String? splitId = isSharedRoomExpense ? 'split-$nowMs' : null;
    final newTx = ExpenseTransaction(
      id: 'tx-$nowMs',
      rawInput: rawInput.trim(),
      title: parsed.itemTitle,
      amountVnd: parsed.amountVnd,
      category: parsed.category,
      timestamp: DateTime.now(),
      payerName: payer,
      routeTier: parsed.routeTier,
      latencyMs: parsed.latencyMs,
      savageRoast: roastText,
      coachAdvice: coachText,
      isSettled: !isSharedRoomExpense,
      linkedSplitId: splitId,
    );

    List<RoommateSplitItem> updatedSplits = state.splitItems;
    Map<String, bool> updatedSettled = state.settledByMember;
    if (isSharedRoomExpense && splitId != null) {
      final newSplit = RoommateSplitItem(
        id: splitId,
        title: '${parsed.category.emoji} ${parsed.itemTitle}',
        totalAmountVnd: parsed.amountVnd,
        assignedRoommates: List<String>.from(state.members),
      );
      updatedSplits = [newSplit, ...state.splitItems];
      updatedSettled = {
        for (final m in state.members) m: false,
      };
    }

    state = state.copyWith(
      transactions: [...state.transactions, newTx],
      splitItems: updatedSplits,
      settledByMember: updatedSettled,
      dailySafeToSpend: updatedSafeToday,
      predictedRunwayDays: updatedRunwayDays,
      noBobaStreakDays: updatedStreak,
      latestSpeechBubble:
          state.activePersona == PersonaMode.savage ? roastText : coachText,
      tier1QueryCount: parsed.routeTier == NlpRouteTier.tier1LocalRegex
          ? state.tier1QueryCount + 1
          : state.tier1QueryCount,
      tier2QueryCount: parsed.routeTier == NlpRouteTier.tier2DeepLlm
          ? state.tier2QueryCount + 1
          : state.tier2QueryCount,
    );
    _persistState();
    return true;
  }

  /// Adds OCR-extracted items from a receipt scan under Tier-2 telemetry only.
  void addMultiItemReceiptScan({
    OcrReceiptTemplate template = OcrReceiptTemplate.circleK,
  }) {
    final now = DateTime.now();
    final int baseMs = now.millisecondsSinceEpoch;
    final String payer = state.activePayer;
    final bool isDormTemplate = template == OcrReceiptTemplate.dormUtilities;
    final int memberCount = state.members.isEmpty ? 1 : state.members.length;

    int runningTotalSpent = state.totalSpentThisMonth;
    int runningSafeToday = state.dailySafeToSpend;
    final int baseAllowance =
        state.dailyBaseAllowance <= 0 ? 1 : state.dailyBaseAllowance;

    final List<ExpenseTransaction> ocrTransactions = [];
    final List<RoommateSplitItem> addedSplits = [];
    bool hasBobaItem = false;

    for (int i = 0; i < template.items.length; i++) {
      final item = template.items[i];
      if (item.category == ExpenseCategory.bobaAndCafe) {
        hasBobaItem = true;
      }
      runningTotalSpent += item.amount;
      final int personalImpact = isDormTemplate
          ? (item.amount / memberCount).round()
          : item.amount;
      runningSafeToday =
          (runningSafeToday - personalImpact).clamp(0, state.dailyBaseAllowance);
      final int remainingMonth =
          (state.monthlyBudget - runningTotalSpent).clamp(0, state.monthlyBudget);
      final int runway =
          (remainingMonth / baseAllowance).floor().clamp(1, 30);
      final String? splitId = isDormTemplate ? 'split-ocr-$baseMs-$i' : null;

      ocrTransactions.add(
        ExpenseTransaction(
          id: 'tx-ocr-$baseMs-$i',
          rawInput: '[OCR ${template.label}] ${item.title}',
          title: item.title,
          amountVnd: item.amount,
          category: item.category,
          timestamp: now.add(Duration(milliseconds: i)),
          payerName: payer,
          routeTier: NlpRouteTier.tier2DeepLlm,
          latencyMs: 620.0,
          savageRoast: HybridNlpService.generatePersonaResponse(
            mode: PersonaMode.savage,
            itemTitle: item.title,
            amountVnd: item.amount,
            category: item.category,
            remainingDailySafeVnd: runningSafeToday,
            predictedRunwayDays: runway,
            payerName: payer,
          ),
          coachAdvice: HybridNlpService.generatePersonaResponse(
            mode: PersonaMode.coach,
            itemTitle: item.title,
            amountVnd: item.amount,
            category: item.category,
            remainingDailySafeVnd: runningSafeToday,
            predictedRunwayDays: runway,
            payerName: payer,
          ),
          isSettled: !isDormTemplate,
          linkedSplitId: splitId,
        ),
      );

      if (isDormTemplate && splitId != null) {
        addedSplits.add(
          RoommateSplitItem(
            id: splitId,
            title: '${item.category.emoji} ${item.title}',
            totalAmountVnd: item.amount,
            assignedRoommates: List<String>.from(state.members),
          ),
        );
      }
    }

    final int finalRemaining =
        (state.monthlyBudget - runningTotalSpent).clamp(0, state.monthlyBudget);
    final int finalRunway =
        (finalRemaining / baseAllowance).floor().clamp(1, 30);
    final String formattedTotal = HybridNlpService.formatVnd(template.totalVnd);

    final String summaryRoast =
        'Quét 1 tờ bill ${template.label} ra liền ${template.items.length} món ($formattedTotal)! Vision AI bắt bài không trượt phát nào! 🧾🔥';
    final String summaryCoach =
        'Vision OCR đã bóc tách tự động ${template.items.length} món từ hóa đơn ${template.label} ($formattedTotal) trong 0.6s. Tiết kiệm 45 giây nhập tay! 🧾✨';

    state = state.copyWith(
      transactions: [...state.transactions, ...ocrTransactions],
      splitItems:
          addedSplits.isNotEmpty ? [...addedSplits, ...state.splitItems] : null,
      settledByMember: isDormTemplate ? const {} : null,
      dailySafeToSpend: runningSafeToday,
      predictedRunwayDays: finalRunway,
      noBobaStreakDays: hasBobaItem ? 0 : state.noBobaStreakDays,
      tier2QueryCount: state.tier2QueryCount + 1,
      latestSpeechBubble:
          state.activePersona == PersonaMode.savage ? summaryRoast : summaryCoach,
    );
    _persistState();
  }

  String _inferredSplitIdForTx(ExpenseTransaction tx) {
    if (tx.linkedSplitId != null && tx.linkedSplitId!.isNotEmpty) {
      return tx.linkedSplitId!;
    }
    if (tx.id.startsWith('tx-')) {
      return 'split-${tx.id.substring(3)}';
    }
    return '';
  }

  int _calculateDailySafeToSpend({
    required List<ExpenseTransaction> transactions,
    required List<RoommateSplitItem> splitItems,
    required Map<String, bool> settledByMember,
  }) {
    final int memberCount = state.members.isEmpty ? 1 : state.members.length;
    int totalPersonalSpentToday = 0;
    for (final tx in transactions) {
      if (tx.id == 'tx-hung-3') continue;
      final String splitId = _inferredSplitIdForTx(tx);
      final bool isShared =
          splitId.isNotEmpty && splitItems.any((s) => s.id == splitId);
      totalPersonalSpentToday +=
          isShared ? (tx.amountVnd / memberCount).round() : tx.amountVnd;
    }

    int settledBoost = 0;
    for (final entry in settledByMember.entries) {
      if (entry.value) {
        for (final item in splitItems) {
          if (item.assignedRoommates.contains(entry.key) &&
              item.assignedRoommates.isNotEmpty) {
            settledBoost +=
                (item.totalAmountVnd / item.assignedRoommates.length).round();
          }
        }
      }
    }

    return (state.dailyBaseAllowance - totalPersonalSpentToday + settledBoost)
        .clamp(0, state.dailyBaseAllowance * 3);
  }

  void editTransaction(
    String txId, {
    required String title,
    required int amountVnd,
    required ExpenseCategory category,
    required String payerName,
  }) {
    final idx = state.transactions.indexWhere((t) => t.id == txId);
    if (idx == -1) return;

    final oldTx = state.transactions[idx];
    final String splitId = _inferredSplitIdForTx(oldTx);
    final bool hasLinkedSplit =
        splitId.isNotEmpty && state.splitItems.any((s) => s.id == splitId);

    List<RoommateSplitItem> updatedSplits = state.splitItems;
    if (hasLinkedSplit) {
      updatedSplits = state.splitItems.map((item) {
        if (item.id != splitId) return item;
        return item.copyWith(
          title: '${category.emoji} ${title.trim()}',
          totalAmountVnd: amountVnd,
        );
      }).toList();
    }

    final List<ExpenseTransaction> updatedList =
        List<ExpenseTransaction>.from(state.transactions);
    updatedList[idx] = oldTx.copyWith(
      title: title.trim(),
      amountVnd: amountVnd,
      category: category,
      payerName: payerName,
    );

    final int updatedSafeToday = _calculateDailySafeToSpend(
      transactions: updatedList,
      splitItems: updatedSplits,
      settledByMember: state.settledByMember,
    );

    final int newTotalSpent =
        updatedList.fold(0, (sum, item) => sum + item.amountVnd);
    final int remainingMonth =
        (state.monthlyBudget - newTotalSpent).clamp(0, state.monthlyBudget);
    final int baseAllowance =
        state.dailyBaseAllowance <= 0 ? 1 : state.dailyBaseAllowance;
    final int updatedRunway =
        (remainingMonth / baseAllowance).floor().clamp(1, 30);

    final String newRoast = HybridNlpService.generatePersonaResponse(
      mode: PersonaMode.savage,
      itemTitle: title.trim(),
      amountVnd: amountVnd,
      category: category,
      remainingDailySafeVnd: updatedSafeToday,
      predictedRunwayDays: updatedRunway,
      payerName: payerName,
    );
    final String newCoach = HybridNlpService.generatePersonaResponse(
      mode: PersonaMode.coach,
      itemTitle: title.trim(),
      amountVnd: amountVnd,
      category: category,
      remainingDailySafeVnd: updatedSafeToday,
      predictedRunwayDays: updatedRunway,
      payerName: payerName,
    );

    updatedList[idx] = updatedList[idx].copyWith(
      savageRoast: newRoast,
      coachAdvice: newCoach,
    );

    int updatedStreak = state.noBobaStreakDays;
    if (category == ExpenseCategory.bobaAndCafe) {
      updatedStreak = 0;
    } else if (oldTx.category == ExpenseCategory.bobaAndCafe &&
        !updatedList.any((t) => t.category == ExpenseCategory.bobaAndCafe)) {
      updatedStreak = state.noBobaStreakDays == 0 ? 5 : state.noBobaStreakDays;
    }

    final bool isLatest = idx == updatedList.length - 1;
    final String updatedBubble = isLatest
        ? (state.activePersona == PersonaMode.savage ? newRoast : newCoach)
        : state.latestSpeechBubble;

    state = state.copyWith(
      transactions: updatedList,
      splitItems: updatedSplits,
      dailySafeToSpend: updatedSafeToday,
      predictedRunwayDays: updatedRunway,
      noBobaStreakDays: updatedStreak,
      latestSpeechBubble: updatedBubble,
    );
    _persistState();
  }

  ({ExpenseTransaction transaction, RoommateSplitItem? linkedSplit})?
      deleteTransaction(String txId) {
    final idx = state.transactions.indexWhere((t) => t.id == txId);
    if (idx == -1) return null;
    final removed = state.transactions[idx];
    final updatedList = List<ExpenseTransaction>.from(state.transactions)
      ..removeAt(idx);

    final String splitId = _inferredSplitIdForTx(removed);
    RoommateSplitItem? removedSplit;
    List<RoommateSplitItem> updatedSplits = state.splitItems;
    if (splitId.isNotEmpty) {
      final splitIdx = state.splitItems.indexWhere((s) => s.id == splitId);
      if (splitIdx != -1) {
        removedSplit = state.splitItems[splitIdx];
        updatedSplits = List<RoommateSplitItem>.from(state.splitItems)
          ..removeAt(splitIdx);
      }
    }

    final int updatedSafeToday = _calculateDailySafeToSpend(
      transactions: updatedList,
      splitItems: updatedSplits,
      settledByMember: state.settledByMember,
    );
    final int newTotalSpent =
        updatedList.fold(0, (sum, item) => sum + item.amountVnd);
    final int remainingMonth =
        (state.monthlyBudget - newTotalSpent).clamp(0, state.monthlyBudget);
    final int baseAllowance =
        state.dailyBaseAllowance <= 0 ? 1 : state.dailyBaseAllowance;
    final int updatedRunway =
        (remainingMonth / baseAllowance).floor().clamp(1, 30);

    int updatedStreak = state.noBobaStreakDays;
    if (removed.category == ExpenseCategory.bobaAndCafe &&
        !updatedList.any((t) => t.category == ExpenseCategory.bobaAndCafe) &&
        updatedStreak == 0) {
      updatedStreak = 5;
    }

    final String bubble = updatedList.isNotEmpty
        ? (state.activePersona == PersonaMode.savage
            ? updatedList.last.savageRoast
            : updatedList.last.coachAdvice)
        : 'Ví đang sạch bóng 0đ chi tiêu! Gõ món đầu tiên để mình thẩm định nhé! ✨';

    state = state.copyWith(
      transactions: updatedList,
      splitItems: updatedSplits,
      dailySafeToSpend: updatedSafeToday,
      predictedRunwayDays: updatedRunway,
      noBobaStreakDays: updatedStreak,
      latestSpeechBubble: bubble,
    );
    _persistState();
    return (transaction: removed, linkedSplit: removedSplit);
  }

  void restoreDeletedTransaction(
    ExpenseTransaction tx, {
    RoommateSplitItem? linkedSplit,
  }) {
    if (state.transactions.any((t) => t.id == tx.id)) return;

    final updatedList = [...state.transactions, tx]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final List<RoommateSplitItem> updatedSplits = linkedSplit != null &&
            !state.splitItems.any((s) => s.id == linkedSplit.id)
        ? [linkedSplit, ...state.splitItems]
        : state.splitItems;

    final int updatedSafeToday = _calculateDailySafeToSpend(
      transactions: updatedList,
      splitItems: updatedSplits,
      settledByMember: state.settledByMember,
    );
    final int newTotalSpent =
        updatedList.fold(0, (sum, item) => sum + item.amountVnd);
    final int remainingMonth =
        (state.monthlyBudget - newTotalSpent).clamp(0, state.monthlyBudget);
    final int baseAllowance =
        state.dailyBaseAllowance <= 0 ? 1 : state.dailyBaseAllowance;
    final int updatedRunway =
        (remainingMonth / baseAllowance).floor().clamp(1, 30);

    state = state.copyWith(
      transactions: updatedList,
      splitItems: updatedSplits,
      dailySafeToSpend: updatedSafeToday,
      predictedRunwayDays: updatedRunway,
      noBobaStreakDays: tx.category == ExpenseCategory.bobaAndCafe
          ? 0
          : state.noBobaStreakDays,
      latestSpeechBubble: state.activePersona == PersonaMode.savage
          ? tx.savageRoast
          : tx.coachAdvice,
    );
    _persistState();
  }

  void addCustomSplitItem(String title, int amountVnd) {
    final newItem = RoommateSplitItem(
      id: 'split-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      totalAmountVnd: amountVnd,
      assignedRoommates: List<String>.from(state.members),
    );
    state = state.copyWith(
      splitItems: [newItem, ...state.splitItems],
      settledByMember: const {},
    );
    _persistState();
  }

  RoommateSplitItem? deleteSplitItem(String itemId) {
    final idx = state.splitItems.indexWhere((i) => i.id == itemId);
    if (idx == -1) return null;
    final removed = state.splitItems[idx];
    final updated = List<RoommateSplitItem>.from(state.splitItems)
      ..removeAt(idx);
    state = state.copyWith(
      splitItems: updated,
    );
    _persistState();
    return removed;
  }

  void restoreDeletedSplitItem(RoommateSplitItem item) {
    if (state.splitItems.any((s) => s.id == item.id)) return;
    state = state.copyWith(
      splitItems: [item, ...state.splitItems],
    );
    _persistState();
  }

  void toggleRoommateOnSplitItem(String itemId, String roommate) {
    final updatedItems = state.splitItems.map((item) {
      if (item.id != itemId) return item;
      final currentList = List<String>.from(item.assignedRoommates);
      if (currentList.contains(roommate)) {
        if (currentList.length > 1) {
          currentList.remove(roommate);
        }
      } else {
        currentList.add(roommate);
      }
      return item.copyWith(assignedRoommates: currentList);
    }).toList();

    final updatedSettled = Map<String, bool>.from(state.settledByMember)
      ..[roommate] = false;

    state = state.copyWith(
      splitItems: updatedItems,
      settledByMember: updatedSettled,
    );
    _persistState();
  }

  void selectRoommateForQr(String roommate) {
    state = state.copyWith(
      selectedRoommateForQr: roommate,
    );
    _persistState();
  }

  /// Allows Treasurer/User to manually mark a roommate as settled or un-settled (e.g. cash/Momo or test reset).
  void toggleMemberSettled(String member) {
    final bool currentlySettled = state.isMemberSettled(member);
    final int shareAmount = state.shareForRoommate(member);
    final String memo = VietQrService.buildReconciliationMemo(
      groupName: state.groupName,
      memberName: member,
    );

    final Map<String, bool> updatedSettled =
        Map<String, bool>.from(state.settledByMember)
          ..[member] = !currentlySettled;

    if (!currentlySettled) {
      final int boostedSafe = (state.dailySafeToSpend + shareAmount)
          .clamp(0, state.dailyBaseAllowance * 3);
      final int boostedRunway = (state.predictedRunwayDays + 2).clamp(1, 30);
      final updatedTransactions = state.transactions.map((tx) {
        if (!tx.isSettled && tx.payerName == member) {
          return tx.copyWith(isSettled: true);
        }
        return tx;
      }).toList();

      state = state.copyWith(
        settledByMember: updatedSettled,
        dailySafeToSpend: boostedSafe,
        predictedRunwayDays: boostedRunway,
        transactions: updatedTransactions,
        latestSpeechBubble: state.activePersona == PersonaMode.savage
            ? 'Ting ting! Đã chốt gạch nợ ${HybridNlpService.formatVnd(shareAmount)} cho $member (mã $memo)! Ví hồi máu cực mạnh! 🎉💸'
            : 'Đã đánh dấu hoàn tất khoản ${HybridNlpService.formatVnd(shareAmount)} của $member (mã $memo). ✅',
      );
    } else {
      final int revertedSafe = (state.dailySafeToSpend - shareAmount)
          .clamp(0, state.dailyBaseAllowance * 3);
      final int revertedRunway = (state.predictedRunwayDays - 2).clamp(1, 30);

      state = state.copyWith(
        settledByMember: updatedSettled,
        dailySafeToSpend: revertedSafe,
        predictedRunwayDays: revertedRunway,
        latestSpeechBubble:
            'Đã đặt lại trạng thái của $member về "Chờ trả" (${HybridNlpService.formatVnd(shareAmount)}). 🔄',
      );
    }
    _persistState();
  }

  /// Idempotent settlement per roommate: credits wallet strictly once per member.
  Future<void> triggerVietQrReconciliation({
    Duration simulatedLatency = const Duration(milliseconds: 1200),
  }) async {
    if (state.isWebhookListening) return;
    final String targetMember = state.selectedRoommateForQr;
    final bool alreadySettled = state.isMemberSettled(targetMember);

    state = state.copyWith(isWebhookListening: true);
    if (simulatedLatency > Duration.zero) {
      await Future.delayed(simulatedLatency);
    }

    final int reimbursedAmount = state.shareForRoommate(targetMember);
    final String memo = VietQrService.buildReconciliationMemo(
      groupName: state.groupName,
      memberName: targetMember,
    );

    if (alreadySettled) {
      state = state.copyWith(
        isWebhookListening: false,
        latestSpeechBubble: state.activePersona == PersonaMode.savage
            ? '$targetMember đã gạch nợ mã $memo rồi! Không cần đòi lại lần 2 đâu nhé! ✅'
            : 'Khoản của $targetMember (mã $memo) đã được đối soát trước đó rồi. ✅',
      );
      _persistState();
      return;
    }

    final Map<String, bool> updatedSettled =
        Map<String, bool>.from(state.settledByMember)..[targetMember] = true;

    final int boostedSafeToSpend = (state.dailySafeToSpend + reimbursedAmount)
        .clamp(0, state.dailyBaseAllowance * 3);
    final int boostedRunway = (state.predictedRunwayDays + 2).clamp(1, 30);

    final updatedTransactions = state.transactions.map((tx) {
      if (!tx.isSettled && tx.payerName == targetMember) {
        return tx.copyWith(isSettled: true);
      }
      return tx;
    }).toList();

    state = state.copyWith(
      isWebhookListening: false,
      settledByMember: updatedSettled,
      dailySafeToSpend: boostedSafeToSpend,
      predictedRunwayDays: boostedRunway,
      transactions: updatedTransactions,
      latestSpeechBubble: state.activePersona == PersonaMode.savage
          ? 'Ting ting! $targetMember vừa chuyển khoản ${HybridNlpService.formatVnd(reimbursedAmount)} mã $memo! Hồi máu thành công, khỏi phải đòi nợ thuê! 🎉💸'
          : 'Tuyệt vời! Đã gạch nợ tự động ${HybridNlpService.formatVnd(reimbursedAmount)} từ $targetMember (mã $memo). Quỹ sinh tồn vừa tăng thêm 2 ngày! 🌱✅',
    );
    _persistState();
  }

  void updateGroupSettings({
    required String groupName,
    required List<String> members,
    required String treasurerName,
    required String bankBin,
    required String bankAccount,
    required int monthlyBudget,
  }) {
    final cleanedMembers = members
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();
    if (cleanedMembers.isEmpty) return;

    final String validGroup =
        groupName.trim().isEmpty ? state.groupName : groupName.trim();
    final String validTreasurer = cleanedMembers.contains(treasurerName)
        ? treasurerName
        : cleanedMembers.first;
    final String validPayer = cleanedMembers.contains(state.activePayer)
        ? state.activePayer
        : cleanedMembers.first;
    final String validQrMember =
        cleanedMembers.contains(state.selectedRoommateForQr)
            ? state.selectedRoommateForQr
            : (cleanedMembers.length > 1
                ? cleanedMembers[1]
                : cleanedMembers.first);

    final int validBudget = monthlyBudget.clamp(500000, 100000000);
    final int newDailyBase = (validBudget / 30).round().clamp(20000, 10000000);

    final int spentToday = (state.dailyBaseAllowance - state.dailySafeToSpend)
        .clamp(0, validBudget);
    final int updatedSafeToday =
        (newDailyBase - spentToday).clamp(0, newDailyBase);
    final int remainingMonth =
        (validBudget - state.totalSpentThisMonth).clamp(0, validBudget);
    final int updatedRunway =
        (remainingMonth / newDailyBase).floor().clamp(1, 30);

    final updatedSplits = state.splitItems.map((item) {
      final filtered = item.assignedRoommates
          .where((r) => cleanedMembers.contains(r))
          .toList();
      return item.copyWith(
        assignedRoommates: filtered.isEmpty ? cleanedMembers : filtered,
      );
    }).toList();

    final Map<String, bool> updatedSettled = {
      for (final m in cleanedMembers)
        m: state.settledByMember[m] ?? false,
    };

    state = state.copyWith(
      groupName: validGroup,
      members: cleanedMembers,
      treasurerName: validTreasurer,
      bankBin: bankBin.trim().isEmpty ? state.bankBin : bankBin.trim(),
      bankAccount:
          bankAccount.trim().isEmpty ? state.bankAccount : bankAccount.trim(),
      monthlyBudget: validBudget,
      dailyBaseAllowance: newDailyBase,
      dailySafeToSpend: updatedSafeToday,
      predictedRunwayDays: updatedRunway,
      activePayer: validPayer,
      selectedRoommateForQr: validQrMember,
      splitItems: updatedSplits,
      settledByMember: updatedSettled,
    );
    _persistState();
  }

  void updateSimulatedMau(double newMau) {
    state = state.copyWith(simulatedMau: newMau);
    _persistState();
  }

  void resetDemo() {
    final currentTheme = state.isDarkMode;
    state = _buildDemoPresetState().copyWith(
      isDarkMode: currentTheme,
      hasCompletedOnboarding: true,
    );
    _persistState();
  }

  /// Creates a 100% blank wallet tailored for a brand-new user with 0 pre-filled expenses.
  void completeNewUserOnboarding({
    required String groupName,
    required List<String> members,
    required int monthlyBudget,
    required PersonaMode activePersona,
    String bankBin = '970422',
    String bankAccount = '0988882026',
  }) {
    final cleanedMembers = members
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();
    final validMembers = cleanedMembers.isEmpty ? ['Bạn'] : cleanedMembers;
    final validGroup = groupName.trim().isEmpty
        ? (validMembers.length == 1 ? 'Ví ${validMembers.first}' : 'Nhóm mới')
        : groupName.trim();
    final validBudget = monthlyBudget.clamp(500000, 100000000);
    final dailyBase = (validBudget / 30).round().clamp(20000, 10000000);
    final qrTarget = validMembers.length > 1 ? validMembers[1] : validMembers.first;

    state = SavageBotState(
      groupName: validGroup,
      members: validMembers,
      treasurerName: validMembers.first,
      bankBin: bankBin.trim().isEmpty ? '970422' : bankBin.trim(),
      bankAccount: bankAccount.trim().isEmpty ? '0988882026' : bankAccount.trim(),
      monthlyBudget: validBudget,
      dailyBaseAllowance: dailyBase,
      dailySafeToSpend: dailyBase,
      predictedRunwayDays: 30,
      noBobaStreakDays: 0,
      activePersona: activePersona,
      activePayer: validMembers.first,
      transactions: const [],
      latestSpeechBubble: activePersona == PersonaMode.savage
          ? 'Chào ${validMembers.first}! Ví mới ${HybridNlpService.formatVnd(validBudget)}/tháng đã sẵn sàng. Gõ thử khoản chi đầu tiên đi, đừng để tớ phải "khịa" ngay ngày đầu! 🔥'
          : 'Chào mừng ${validMembers.first}! Ngân sách ${HybridNlpService.formatVnd(validBudget)}/tháng đã được thiết lập (hạn mức ${HybridNlpService.formatVnd(dailyBase)}/ngày). Hãy ghi khoản chi đầu tiên nhé! 🌱',
      splitItems: const [],
      selectedRoommateForQr: qrTarget,
      settledByMember: const {},
      isWebhookListening: false,
      tier1QueryCount: 0,
      tier2QueryCount: 0,
      simulatedMau: 25000,
      isDarkMode: state.isDarkMode,
      hasCompletedOnboarding: true,
    );
    _persistState();
  }

  /// Clears saved wallet and returns to the brand-new user onboarding setup.
  Future<void> startFreshUserReset() async {
    final currentTheme = state.isDarkMode;
    state = _buildFreshUserState(isDarkMode: currentTheme);
    if (!enablePersistence) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {
      // Ignore storage clear errors
    }
  }
}

final savageBotProvider =
    StateNotifierProvider<SavageBotNotifier, SavageBotState>((ref) {
  return SavageBotNotifier();
});
