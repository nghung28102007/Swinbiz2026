import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum PersonaMode {
  savage, // "Chế độ Mỏ Hỗn"
  coach,  // "Chế độ Quân Sư"
}

enum ExpenseCategory {
  foodAndDrink,
  bobaAndCafe,
  transport,
  dormAndUtilities,
  entertainment,
  other,
}

extension ExpenseCategoryExtension on ExpenseCategory {
  String get labelVi {
    switch (this) {
      case ExpenseCategory.foodAndDrink:
        return 'Ăn uống';
      case ExpenseCategory.bobaAndCafe:
        return 'Trà sữa & Cafe';
      case ExpenseCategory.transport:
        return 'Di chuyển';
      case ExpenseCategory.dormAndUtilities:
        return 'Phòng trọ & Điện nước';
      case ExpenseCategory.entertainment:
        return 'Giải trí & Mua sắm';
      case ExpenseCategory.other:
        return 'Chi tiêu khác';
    }
  }

  String get emoji {
    switch (this) {
      case ExpenseCategory.foodAndDrink:
        return '🍜';
      case ExpenseCategory.bobaAndCafe:
        return '🧋';
      case ExpenseCategory.transport:
        return '🛵';
      case ExpenseCategory.dormAndUtilities:
        return '⚡';
      case ExpenseCategory.entertainment:
        return '🎮';
      case ExpenseCategory.other:
        return '💳';
    }
  }

  Color get color {
    switch (this) {
      case ExpenseCategory.foodAndDrink:
        return const Color(0xFF10B981);
      case ExpenseCategory.bobaAndCafe:
        return const Color(0xFFF43F5E);
      case ExpenseCategory.transport:
        return const Color(0xFF3B82F6);
      case ExpenseCategory.dormAndUtilities:
        return const Color(0xFFF59E0B);
      case ExpenseCategory.entertainment:
        return const Color(0xFF8B5CF6);
      case ExpenseCategory.other:
        return const Color(0xFF64748B);
    }
  }
}

enum NlpRouteTier {
  tier1LocalRegex, // 0 VND API Cost, <10ms on-device execution
  tier2DeepLlm,    // Complex multi-turn / OCR / semantic advisory
}

class ParsedExpenseResult {
  final String rawQuery;
  final String itemTitle;
  final int amountVnd;
  final ExpenseCategory category;
  final NlpRouteTier routeTier;
  final double latencyMs;
  final int estimatedTokenCostVnd;

  const ParsedExpenseResult({
    required this.rawQuery,
    required this.itemTitle,
    required this.amountVnd,
    required this.category,
    required this.routeTier,
    required this.latencyMs,
    required this.estimatedTokenCostVnd,
  });
}

class ExpenseTransaction {
  final String id;
  final String rawInput;
  final String title;
  final int amountVnd;
  final ExpenseCategory category;
  final DateTime timestamp;
  final String payerName; // e.g., "Duy", "Tuất", "Hưng"
  final NlpRouteTier routeTier;
  final double latencyMs;
  final String savageRoast;
  final String coachAdvice;
  final bool isSettled;
  final String? linkedSplitId;

  const ExpenseTransaction({
    required this.id,
    required this.rawInput,
    required this.title,
    required this.amountVnd,
    required this.category,
    required this.timestamp,
    required this.payerName,
    required this.routeTier,
    this.latencyMs = 1.4,
    required this.savageRoast,
    required this.coachAdvice,
    this.isSettled = true,
    this.linkedSplitId,
  });

  ExpenseTransaction copyWith({
    String? id,
    String? rawInput,
    String? title,
    int? amountVnd,
    ExpenseCategory? category,
    DateTime? timestamp,
    String? payerName,
    NlpRouteTier? routeTier,
    double? latencyMs,
    String? savageRoast,
    String? coachAdvice,
    bool? isSettled,
    String? linkedSplitId,
  }) {
    return ExpenseTransaction(
      id: id ?? this.id,
      rawInput: rawInput ?? this.rawInput,
      title: title ?? this.title,
      amountVnd: amountVnd ?? this.amountVnd,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      payerName: payerName ?? this.payerName,
      routeTier: routeTier ?? this.routeTier,
      latencyMs: latencyMs ?? this.latencyMs,
      savageRoast: savageRoast ?? this.savageRoast,
      coachAdvice: coachAdvice ?? this.coachAdvice,
      isSettled: isSettled ?? this.isSettled,
      linkedSplitId: linkedSplitId ?? this.linkedSplitId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rawInput': rawInput,
      'title': title,
      'amountVnd': amountVnd,
      'category': category.name,
      'timestamp': timestamp.toIso8601String(),
      'payerName': payerName,
      'routeTier': routeTier.name,
      'latencyMs': latencyMs,
      'savageRoast': savageRoast,
      'coachAdvice': coachAdvice,
      'isSettled': isSettled,
      if (linkedSplitId != null) 'linkedSplitId': linkedSplitId,
    };
  }

  factory ExpenseTransaction.fromJson(Map<String, dynamic> json) {
    return ExpenseTransaction(
      id: json['id'] as String? ?? '',
      rawInput: json['rawInput'] as String? ?? '',
      title: json['title'] as String? ?? '',
      amountVnd: (json['amountVnd'] as num?)?.toInt() ?? 0,
      category: ExpenseCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => ExpenseCategory.other,
      ),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      payerName: json['payerName'] as String? ?? 'Bạn',
      routeTier: NlpRouteTier.values.firstWhere(
        (t) => t.name == json['routeTier'],
        orElse: () => NlpRouteTier.tier1LocalRegex,
      ),
      latencyMs: (json['latencyMs'] as num?)?.toDouble() ?? 1.4,
      savageRoast: json['savageRoast'] as String? ?? '',
      coachAdvice: json['coachAdvice'] as String? ?? '',
      isSettled: json['isSettled'] as bool? ?? true,
      linkedSplitId: json['linkedSplitId'] as String?,
    );
  }
}

class HybridNlpService {
  static final NumberFormat _vndFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  static String formatVnd(num amount) {
    return _vndFormat.format(amount.round());
  }

  static String formatCompactVnd(num amount) {
    final val = amount.abs();
    if (val >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(2)}M đ';
    }
    if (val >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k đ';
    }
    return '${amount.round()}đ';
  }

  /// Tier-1 On-Device Regex Parser (0 VND API Cost, <10ms latency)
  /// Automatically extracts item name, category, and amount from Vietnamese
  /// typed shorthand or Speech-to-Text spoken phrases.
  static ParsedExpenseResult? parseNaturalInput(String rawInput) {
    final cleaned = rawInput.trim();
    if (cleaned.isEmpty) return null;

    final String normalized = _normalizeSpokenAndFormattedAmounts(cleaned);

    // 1. Compound Vietnamese slang with "rưỡi" (e.g. "1 củ rưỡi", "2 lít rưỡi", "3 trăm rưỡi")
    final RegExp halfUnitRegex = RegExp(
      r'(\d+)\s*(củ|triệu|tr|m|lít|trăm)\s*rưỡi(?:\s*(?:nghìn|ngàn|đồng|đ|vnd))?(?=\s|$|[.,!?;:)])',
      caseSensitive: false,
    );
    final halfMatch = halfUnitRegex.firstMatch(normalized);
    if (halfMatch != null) {
      final int major = int.tryParse(halfMatch.group(1)!) ?? 0;
      final String unit = halfMatch.group(2)!.toLowerCase();
      final bool isMillionUnit =
          unit == 'củ' || unit == 'triệu' || unit == 'tr' || unit == 'm';
      final int unitMultiplier = isMillionUnit ? 1000000 : 100000;
      final int totalAmount = major * unitMultiplier + (unitMultiplier ~/ 2);
      return _buildParsedResult(
        rawQuery: cleaned,
        itemText: normalized.replaceRange(halfMatch.start, halfMatch.end, ''),
        fallbackTitle: 'Khoản chi tiêu',
        amountVnd: totalAmount,
      );
    }

    // 2. Compound slang like "1 củ 2" (1,200,000), "2 lít 5" (250,000), "3 trăm 5" (350,000), "1 triệu 500k"
    final RegExp compoundUnitRegex = RegExp(
      r'(\d+)\s*(củ|triệu|tr|m|lít|trăm)\s*(\d+)(?:\s*(?:k|nghìn|ngàn|trăm|đồng|đ|vnd))?(?=\s|$|[.,!?;:)])',
      caseSensitive: false,
    );
    final compoundMatch = compoundUnitRegex.firstMatch(normalized);
    if (compoundMatch != null) {
      final int major = int.tryParse(compoundMatch.group(1)!) ?? 0;
      final String unit = compoundMatch.group(2)!.toLowerCase();
      final int minor = int.tryParse(compoundMatch.group(3)!) ?? 0;
      final bool isMillionUnit =
          unit == 'củ' || unit == 'triệu' || unit == 'tr' || unit == 'm';
      final int majorMultiplier = isMillionUnit ? 1000000 : 100000;
      final int minorMultiplier = isMillionUnit
          ? (minor < 10 ? 100000 : (minor < 100 ? 10000 : 1000))
          : (minor < 10 ? 10000 : 1000);
      final int totalAmount =
          major * majorMultiplier + (minor * minorMultiplier);
      return _buildParsedResult(
        rawQuery: cleaned,
        itemText:
            normalized.replaceRange(compoundMatch.start, compoundMatch.end, ''),
        fallbackTitle: 'Khoản chi lớn',
        amountVnd: totalAmount,
      );
    }

    // 3. Standard shorthand regex: 35k, 1.2m, 350k, 55000, 45 cành, 2 lít, 3 trăm, 5 chục, 2 củ
    final RegExp shorthandRegex = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(k|nghìn|ngàn|cành|ca|lít|trăm|chục|m|tr|triệu|củ|đồng|đ|vnd)?(?:\s*(?:nghìn|ngàn|đồng|đ|vnd))?(?=\s|$|[.,!?;:)])',
      caseSensitive: false,
    );

    final RegExp identifierPrefixRegex = RegExp(
      r'(?:^|\s)(?:phòng|p\.?|tầng|lầu|tháng|ngày|năm|quận|q\.?|tòa|số)\s*$',
      caseSensitive: false,
    );

    final matches = shorthandRegex.allMatches(normalized).where((m) {
      final hasUnit = (m.group(2) ?? '').isNotEmpty;
      if (hasUnit) return true;
      final prefix = normalized.substring(0, m.start);
      final rawVal = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
      if (rawVal < 10000 && identifierPrefixRegex.hasMatch(prefix)) {
        return false;
      }
      return true;
    }).toList();
    if (matches.isEmpty) return null;

    // Prefer matches that carry an explicit currency/slang unit so trailing room
    // numbers like "35k phòng 302" don't override the actual price.
    final RegExpMatch amountMatch = matches.lastWhere(
      (m) => (m.group(2) ?? '').isNotEmpty,
      orElse: () => matches.last,
    );

    final String rawNumStr = amountMatch.group(1)!.replaceAll(',', '.');
    final String unit = (amountMatch.group(2) ?? '').toLowerCase();

    final double? baseValue = double.tryParse(rawNumStr);
    if (baseValue == null || baseValue <= 0) return null;

    double multiplier = 1.0;
    if (unit == 'k' ||
        unit == 'nghìn' ||
        unit == 'ngàn' ||
        unit == 'cành' ||
        unit == 'ca') {
      multiplier = 1000.0;
    } else if (unit == 'chục') {
      multiplier = 10000.0;
    } else if (unit == 'lít' || unit == 'trăm') {
      multiplier = 100000.0;
    } else if (unit == 'm' || unit == 'tr' || unit == 'triệu' || unit == 'củ') {
      multiplier = 1000000.0;
    } else if (unit.isEmpty && baseValue < 1000) {
      multiplier = 1000.0;
    }

    final int finalAmountVnd = (baseValue * multiplier).round();
    return _buildParsedResult(
      rawQuery: cleaned,
      itemText:
          normalized.replaceRange(amountMatch.start, amountMatch.end, ''),
      fallbackTitle: 'Chi tiêu phát sinh',
      amountVnd: finalAmountVnd,
    );
  }

  static ParsedExpenseResult _buildParsedResult({
    required String rawQuery,
    required String itemText,
    required String fallbackTitle,
    required int amountVnd,
  }) {
    String extractedItem = itemText
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[-:,\s]+|[-:,\s]+$'), '')
        .replaceAll(
          RegExp(
            r'\s+(?:hết|mất|tốn|giá|tầm|khoảng|đồng|vnd|vnđ|đ)$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    if (extractedItem.isEmpty) {
      extractedItem = fallbackTitle;
    } else {
      extractedItem =
          extractedItem[0].toUpperCase() + extractedItem.substring(1);
    }

    final ExpenseCategory category = classifyCategory(extractedItem);
    final String lowerRaw = rawQuery.toLowerCase();
    final bool isComplexQuery = rawQuery.split(RegExp(r'\s+')).length > 8 ||
        lowerRaw.contains('tư vấn') ||
        lowerRaw.contains('phân tích') ||
        lowerRaw.contains('hóa đơn') ||
        lowerRaw.contains('ocr');

    return ParsedExpenseResult(
      rawQuery: rawQuery,
      itemTitle: extractedItem,
      amountVnd: amountVnd,
      category: category,
      routeTier: isComplexQuery
          ? NlpRouteTier.tier2DeepLlm
          : NlpRouteTier.tier1LocalRegex,
      latencyMs: isComplexQuery ? 380.0 : 1.4,
      estimatedTokenCostVnd: isComplexQuery ? 110 : 0,
    );
  }

  /// Detects if a query describes a shared group/dorm expense from keywords or category.
  static bool isLikelySharedExpense(String rawInput, ExpenseCategory category) {
    if (category == ExpenseCategory.dormAndUtilities) return true;
    final lower = rawInput.toLowerCase();
    return lower.contains('chia phòng') ||
        lower.contains('cùng phòng') ||
        lower.contains('cả phòng') ||
        lower.contains('chia tiền') ||
        lower.contains('chia đôi') ||
        lower.contains('chia ba') ||
        lower.contains('chia nhau') ||
        lower.contains('ăn chung') ||
        lower.contains('mua chung') ||
        lower.contains('quỹ phòng') ||
        lower.contains('quỹ nhóm');
  }

  /// Detects if the user explicitly named a group member in the natural query
  /// (e.g. "Tuất uống trà sữa 55k" -> "Tuất").
  static String? detectMemberInQuery(String rawInput, List<String> members) {
    if (members.length <= 1) return null;
    final lowerInput = rawInput.trim().toLowerCase();
    for (final member in members) {
      final cleanMember = member.trim();
      if (cleanMember.isEmpty) continue;
      final lowerMember = cleanMember.toLowerCase();
      final pattern = RegExp(
        '(?:^|\\s|cho\\s+|của\\s+)${RegExp.escape(lowerMember)}(?:\\s|\$)',
        caseSensitive: false,
      );
      if (pattern.hasMatch(lowerInput)) {
        return cleanMember;
      }
    }
    return null;
  }

  /// Normalizes STT spoken Vietnamese number phrases (e.g. "bốn mươi lăm nghìn",
  /// "một triệu hai", "năm chục") and thousand separators ("1.500.000" -> "1500000").
  static String _normalizeSpokenAndFormattedAmounts(String input) {
    String text = input
        .replaceAll('₫', 'đ')
        .replaceAll(RegExp(r'\bvnđ\b', caseSensitive: false), 'vnd');

    // Remove thousand separators like 55.000 or 1.500.000
    text = text.replaceAll(RegExp(r'(?<=\d)[.,](?=\d{3}\b)'), '');

    // Convert spoken Vietnamese number words only when anchored by a money/scale unit
    const Map<String, int> digitWords = {
      'không': 0,
      'một': 1,
      'mốt': 1,
      'hai': 2,
      'ba': 3,
      'bốn': 4,
      'tư': 4,
      'năm': 5,
      'lăm': 5,
      'nhăm': 5,
      'sáu': 6,
      'bảy': 7,
      'bẩy': 7,
      'tám': 8,
      'chín': 9,
    };

    const String wordGroup =
        r'(?:không|một|mốt|hai|ba|bốn|tư|năm|lăm|nhăm|sáu|bảy|bẩy|tám|chín|mười|mươi|linh|lẻ)';
    final RegExp spokenNumberWithUnit = RegExp(
      '(?:^|(?<=\\s))((?:$wordGroup\\s+){1,5}?)(?=(?:k|ca|nghìn|ngàn|cành|lít|trăm|chục|triệu|củ|đồng)(?:\\s|\$|[.,!?;:)]))',
      caseSensitive: false,
    );

    text = text.replaceAllMapped(spokenNumberWithUnit, (match) {
      final String phrase = match.group(1)!.trim().toLowerCase();
      final int? parsed = _parseVietnameseWordNumber(phrase, digitWords);
      if (parsed == null || parsed <= 0) return match.group(0)!;
      return '$parsed ';
    });

    // Convert trailing spoken digit in compound "1 triệu hai" / "1 triệu hai trăm" / "1 củ rưỡi"
    final RegExp trailingWordDigit = RegExp(
      r'(\d+)\s*(củ|triệu|tr|m|lít|trăm)\s+(một|mốt|hai|ba|bốn|tư|năm|lăm|sáu|bảy|bẩy|tám|chín)(?:\s+trăm(?:\s+(?:nghìn|ngàn))?)?(?=\s|$|[.,!?;:)])',
      caseSensitive: false,
    );
    text = text.replaceAllMapped(trailingWordDigit, (m) {
      final int? minor = digitWords[m.group(3)!.toLowerCase()];
      if (minor == null) return m.group(0)!;
      return '${m.group(1)} ${m.group(2)} $minor';
    });

    // Collapse "trăm nghìn" / "trăm ngàn" after a number into "trăm" (100k scale)
    text = text.replaceAllMapped(
      RegExp(
        r'(\d+)\s*trăm(?:\s+rưỡi)?\s+(?:nghìn|ngàn)(?:\s+đồng)?(?=\s|$|[.,!?;:)])',
        caseSensitive: false,
      ),
      (m) => m.group(0)!.replaceAll(
            RegExp(r'\s+(?:nghìn|ngàn)(?:\s+đồng)?$', caseSensitive: false),
            '',
          ),
    );

    // Convert standalone "trăm rưỡi" (no leading number) -> "1 trăm rưỡi"
    text = text.replaceAllMapped(
      RegExp(
        r'(?<!\d\s)(?:^|(?<=\s))(trăm|củ|triệu|lít)\s+rưỡi(?=\s|$|[.,!?;:)])',
        caseSensitive: false,
      ),
      (m) => '1 ${m.group(1)} rưỡi',
    );

    return text;
  }

  static int? _parseVietnameseWordNumber(
    String phrase,
    Map<String, int> digitWords,
  ) {
    final tokens = phrase.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return null;

    if (tokens.length == 1) {
      if (tokens[0] == 'mười') return 10;
      return digitWords[tokens[0]];
    }

    // e.g. "mười lăm", "mười hai"
    if (tokens[0] == 'mười' && tokens.length == 2) {
      final ones = digitWords[tokens[1]];
      if (ones != null) return 10 + ones;
    }

    // e.g. "hai mươi", "bốn mươi lăm", "ba tư"
    final int? first = digitWords[tokens[0]];
    if (first == null) return null;

    if (tokens[1] == 'mươi') {
      if (tokens.length == 2) return first * 10;
      if (tokens.length == 3) {
        final ones = digitWords[tokens[2]];
        if (ones != null) return first * 10 + ones;
      }
    }

    if (tokens.length == 2) {
      final second = digitWords[tokens[1]];
      if (second != null && first >= 2) {
        return first * 10 + second;
      }
    }

    return null;
  }

  static ExpenseCategory classifyCategory(String text) {
    final lower = text.toLowerCase();
    // Check dorm/utilities first when "nước" refers to household water/laundry
    if (lower.contains('trọ') ||
        lower.contains('điện') ||
        lower.contains('wifi') ||
        lower.contains('mạng') ||
        lower.contains('internet') ||
        lower.contains('phòng') ||
        lower.contains('rác') ||
        lower.contains('tiền nước') ||
        lower.contains('nước giặt') ||
        lower.contains('nước rửa') ||
        lower.contains('bình nước') ||
        lower.contains('nước lọc') ||
        lower.contains('xà phòng') ||
        lower.contains('bột giặt') ||
        lower.contains('giấy vệ sinh') ||
        lower.contains('nhà')) {
      return ExpenseCategory.dormAndUtilities;
    }
    if (lower.contains('trà sữa') ||
        lower.contains('cafe') ||
        lower.contains('cà phê') ||
        RegExp(r'(?:^|\s)cf(?:\s|$)').hasMatch(lower) ||
        lower.contains('highlands') ||
        lower.contains('phê la') ||
        lower.contains('koi') ||
        lower.contains('gongcha') ||
        lower.contains('matcha') ||
        lower.contains('katinat') ||
        lower.contains('mixue') ||
        lower.contains('tocotoco') ||
        lower.contains('starbucks') ||
        lower.contains('bạc xỉu') ||
        lower.contains('trà chanh') ||
        lower.contains('trà tắc') ||
        lower.contains('trà đào') ||
        lower.contains('sinh tố') ||
        lower.contains('nước ép') ||
        lower.contains('nước mía') ||
        lower.contains('monster') ||
        lower.contains('redbull') ||
        lower.contains('nước')) {
      return ExpenseCategory.bobaAndCafe;
    }
    if (lower.contains('cơm') ||
        lower.contains('phở') ||
        lower.contains('bún') ||
        lower.contains('hủ tiếu') ||
        lower.contains('miến') ||
        lower.contains('cháo') ||
        lower.contains('xôi') ||
        RegExp(r'(?:^|\s)ăn(?:\s|$)').hasMatch(lower) ||
        lower.contains('mì') ||
        lower.contains('lẩu') ||
        lower.contains('nướng') ||
        lower.contains('bánh') ||
        lower.contains('gà') ||
        lower.contains('bò') ||
        lower.contains('thịt') ||
        lower.contains('ốc') ||
        lower.contains('kfc') ||
        lower.contains('lotteria') ||
        lower.contains('jollibee') ||
        lower.contains('pizza') ||
        lower.contains('burger') ||
        lower.contains('sushi') ||
        lower.contains('tokbokki') ||
        lower.contains('xiên') ||
        lower.contains('chè') ||
        lower.contains('kem') ||
        lower.contains('circle k') ||
        lower.contains('gs25') ||
        lower.contains('winmart') ||
        lower.contains('siêu thị') ||
        lower.contains('tạp hóa') ||
        lower.contains('trưa') ||
        lower.contains('sáng') ||
        lower.contains('tối') ||
        lower.contains('khuya')) {
      return ExpenseCategory.foodAndDrink;
    }
    if (lower.contains('grab') ||
        RegExp(r'(?:^|\s)be(?:\s|$)').hasMatch(lower) ||
        lower.contains('xanh sm') ||
        lower.contains('gojek') ||
        lower.contains('taxi') ||
        lower.contains('xăng') ||
        lower.contains('nhớt') ||
        RegExp(r'(?:^|\s)xe(?:\s|$)').hasMatch(lower) ||
        lower.contains('bus') ||
        lower.contains('buýt') ||
        lower.contains('metro')) {
      return ExpenseCategory.transport;
    }
    if (lower.contains('game') ||
        lower.contains('phim') ||
        lower.contains('cgv') ||
        lower.contains('lotte') ||
        lower.contains('shopee') ||
        lower.contains('lazada') ||
        lower.contains('tiktok') ||
        RegExp(r'(?:^|\s)áo(?:\s|$)').hasMatch(lower) ||
        lower.contains('quần') ||
        lower.contains('giày') ||
        lower.contains('mỹ phẩm') ||
        lower.contains('son') ||
        lower.contains('cắt tóc') ||
        lower.contains('gym') ||
        lower.contains('bida') ||
        lower.contains('karaoke') ||
        lower.contains('netflix') ||
        lower.contains('spotify') ||
        lower.contains('steam') ||
        lower.contains('skin')) {
      return ExpenseCategory.entertainment;
    }
    return ExpenseCategory.other;
  }

  static String generatePersonaResponse({
    required PersonaMode mode,
    required String itemTitle,
    required int amountVnd,
    required ExpenseCategory category,
    required int remainingDailySafeVnd,
    required int predictedRunwayDays,
    required String payerName,
  }) {
    final formattedAmount = formatVnd(amountVnd);
    final formattedSafe = formatVnd(remainingDailySafeVnd);

    if (mode == PersonaMode.savage) {
      if (category == ExpenseCategory.bobaAndCafe) {
        return 'Ê $payerName, lại "$itemTitle" hết $formattedAmount! Đường huyết tăng tỷ lệ nghịch với số dư MB Bank đó chiến thần ơi. Hôm nay chỉ còn được tiêu $formattedSafe thôi nhé! 🧋💀';
      }
      if (category == ExpenseCategory.dormAndUtilities || amountVnd >= 500000) {
        return 'Cú tát tư bản mang tên "$itemTitle" (-$formattedAmount)! Ví $payerName xẹp lép như bánh tráng phơi sương, chuẩn bị chuỗi ngày mì Hảo Hảo cứu net thôi! ⚡💸';
      }
      if (category == ExpenseCategory.transport) {
        return 'Đi có mấy bước chân cũng "$itemTitle" mất $formattedAmount! Đôi chân $payerName sinh ra để làm cảnh hay đang cosplay tổng tài tài chính âm? 🛵🔥';
      }
      if (category == ExpenseCategory.entertainment) {
        return 'Chốt đơn "$itemTitle" ($formattedAmount) nhanh như cách người yêu cũ trở mặt! Còn đúng $predictedRunwayDays ngày sống sót thôi đó $payerName, tém cái tay lại! 🎮👀';
      }
      if (remainingDailySafeVnd < 40000) {
        return 'Gắt đấy $payerName! Vừa bay $formattedAmount cho "$itemTitle", hạn mức hôm nay còn đúng $formattedSafe — đủ mua 2 gói mì cộng 1 quả trứng gà thôi nha! 🍜🚨';
      }
      return 'Đã ghi sổ "$itemTitle" (-$formattedAmount) cho $payerName. Tốc độ quẹt QR nhanh hơn tốc độ chạy deadline ở Swinburne nữa, cẩn thận cuối tháng ăn không khí! 🔥';
    } else {
      final String d10Warning = predictedRunwayDays <= 10
          ? ' ⚠️ Cảnh báo D-10: Quỹ sinh tồn chỉ còn $predictedRunwayDays ngày, ưu tiên cắt giảm trà sữa & mua sắm ngẫu hứng!'
          : ' Quỹ sinh tồn vẫn an toàn cho $predictedRunwayDays ngày tới.';

      if (category == ExpenseCategory.bobaAndCafe) {
        return 'Đã lưu "$itemTitle" ($formattedAmount) cho $payerName. Mẹo Quân Sư: Bớt 2 ly nước ngọt mỗi tuần giúp bạn tiết kiệm ~440.000đ/tháng.$d10Warning 🌱';
      }
      if (category == ExpenseCategory.dormAndUtilities) {
        return 'Khoản chi cố định "$itemTitle" ($formattedAmount) đã được hạch toán. Bạn có thể qua tab "Chia tiền QR" để thu tiền phòng từ các thành viên tự động.$d10Warning 🤝';
      }
      return 'Đã ghi nhận "$itemTitle" ($formattedAmount) của $payerName. Hạn mức an toàn hôm nay còn $formattedSafe mà không ảnh hưởng mục tiêu tiết kiệm.$d10Warning ✨';
    }
  }
}
