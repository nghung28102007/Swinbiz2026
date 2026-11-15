import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  static int _responseVariantCounter = 0;

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
    final lower = itemTitle.toLowerCase();
    final int variant = (_responseVariantCounter++) +
        (mode == PersonaMode.savage ? 0 : 3);

    if (mode == PersonaMode.savage) {
      final List<String> pool = _buildSavagePool(
        lower: lower,
        itemTitle: itemTitle,
        formattedAmount: formattedAmount,
        formattedSafe: formattedSafe,
        amountVnd: amountVnd,
        category: category,
        remainingDailySafeVnd: remainingDailySafeVnd,
        predictedRunwayDays: predictedRunwayDays,
        payerName: payerName,
      );
      return pool[variant % pool.length];
    } else {
      final List<String> pool = _buildCoachPool(
        lower: lower,
        itemTitle: itemTitle,
        formattedAmount: formattedAmount,
        formattedSafe: formattedSafe,
        amountVnd: amountVnd,
        category: category,
        remainingDailySafeVnd: remainingDailySafeVnd,
        predictedRunwayDays: predictedRunwayDays,
        payerName: payerName,
      );
      return pool[variant % pool.length];
    }
  }

  static List<String> _buildSavagePool({
    required String lower,
    required String itemTitle,
    required String formattedAmount,
    required String formattedSafe,
    required int amountVnd,
    required ExpenseCategory category,
    required int remainingDailySafeVnd,
    required int predictedRunwayDays,
    required String payerName,
  }) {
    if (category == ExpenseCategory.bobaAndCafe) {
      if (lower.contains('cafe') ||
          lower.contains('cà phê') ||
          lower.contains('bạc xỉu') ||
          lower.contains('cf')) {
        return [
          '$payerName nạp $formattedAmount tiền "$itemTitle" để tỉnh táo nhìn số dư tài khoản tụt dốc đúng không? Hạn mức ngày giờ chỉ còn $formattedSafe thôi.',
          'Lại một ly "$itemTitle" ($formattedAmount). Caffeine thì giúp $payerName thức chạy deadline, còn chiếc ví thì sắp ngất lâm sàng rồi.',
          'Chi $formattedAmount cho "$itemTitle" — nhịp tim $payerName tăng vì cà phê hay vì nhìn quỹ sống sót chỉ còn $predictedRunwayDays ngày?',
          'Mỗi ngày một cữ "$itemTitle" $formattedAmount thế này thì tháng sau $payerName uống nước lọc đun sôi ngắm phố nhé. Hôm nay còn tiêu được $formattedSafe.',
          'Đầu tư $formattedAmount vào "$itemTitle", tinh thần tỉnh táo 100% nhưng độ dày của ví giảm còn $formattedSafe cho hôm nay.',
        ];
      }
      return [
        'Ê $payerName, lại "$itemTitle" hết $formattedAmount! Đường huyết tăng tỷ lệ nghịch với số dư ngân hàng đó, hôm nay chỉ còn được tiêu $formattedSafe thôi.',
        'Cúng $formattedAmount cho "$itemTitle" nhanh thế $payerName? Cổ đông quán trà sữa chắc phải gửi bằng khen cho bạn, còn ví bạn chỉ trụ được $predictedRunwayDays ngày nữa thôi.',
        'Lại là "$itemTitle" ($formattedAmount)! Bảo giảm ngọt giảm tiêu mà tay $payerName quẹt QR còn nhanh hơn vận tốc ánh sáng. Hạn mức ngày còn $formattedSafe.',
        'Một ly "$itemTitle" giá $formattedAmount đổi lấy 15 phút hạnh phúc và cả tuần cuối tháng ăn mì gói. Suy nghĩ kỹ chưa $payerName?',
        'Chuỗi ngày cai trà sữa của $payerName chính thức bay màu vì "$itemTitle" ($formattedAmount). Quỹ an toàn hôm nay tụt xuống còn $formattedSafe.',
        'Uống "$itemTitle" hết $formattedAmount xong nhớ giữ lại cái ly nhựa để cuối tháng đựng tiền lẻ nhé $payerName. Còn đúng $predictedRunwayDays ngày đường băng thôi.',
      ];
    }

    if (category == ExpenseCategory.dormAndUtilities) {
      return [
        'Cú tát tư bản mang tên "$itemTitle" (-$formattedAmount)! Ví $payerName xẹp đi trông thấy, nhớ đòi tiền phòng anh em ngay kẻo cuối tháng ôm nợ.',
        'Thanh toán "$itemTitle" mất $formattedAmount. Lúc bật điều hòa mát rượi thì cười tươi, lúc nhìn hóa đơn thì $payerName trầm cảm luôn.',
        'Bay nhẹ $formattedAmount cho "$itemTitle". Khoản này mà không chia đều qua VietQR ngay là $payerName xác định gồng lưng cả tháng.',
        'Hóa đơn "$itemTitle" ($formattedAmount) vừa gõ cửa. Số ngày sống khỏe của cả phòng giờ rút ngắn còn $predictedRunwayDays ngày.',
        'Đã trừ $formattedAmount tiền "$itemTitle" của $payerName. Chi phí sinh hoạt thì tăng mà ngân sách ngày giờ chỉ còn $formattedSafe.',
      ];
    }

    if (category == ExpenseCategory.transport) {
      if (lower.contains('xăng') || lower.contains('nhớt')) {
        return [
          'Đổ "$itemTitle" hết $formattedAmount, xe thì đầy bình mà ví $payerName thì cạn bình! Hôm nay chỉ còn dư $formattedSafe thôi.',
          'Nuôi chiến mã tốn $formattedAmount tiền "$itemTitle". Từ mai $payerName bớt lượn lờ hồ Tây không mục đích nhé, quỹ còn $predictedRunwayDays ngày thôi.',
          'Vừa bơm $formattedAmount vào "$itemTitle". Xe chạy êm ru còn tài khoản $payerName kêu gào vì hạn mức ngày chỉ còn $formattedSafe.',
        ];
      }
      return [
        'Đi có mấy bước chân cũng "$itemTitle" mất $formattedAmount! Đôi chân $payerName sinh ra để làm cảnh hay đang nhập vai chủ tịch giả nghèo?',
        'Gọi "$itemTitle" hết $formattedAmount. Ngồi sau xe gió thổi mát mặt nhưng nhìn lại hạn mức ngày còn đúng $formattedSafe thì lạnh sống lưng.',
        'Tốc độ đặt "$itemTitle" ($formattedAmount) của $payerName nhanh thật, cứ đà này $predictedRunwayDays ngày nữa là chuyển sang cuốc bộ toàn tập.',
        'Lại $formattedAmount cho chuyến "$itemTitle". Tiết kiệm được 15 phút đi đường nhưng mất luôn bữa ăn xế của $payerName rồi.',
        'Chi $formattedAmount cho "$itemTitle" — lịch sử di chuyển thì sang chảnh mà số dư hôm nay chỉ còn vỏn vẹn $formattedSafe.',
      ];
    }

    if (category == ExpenseCategory.entertainment) {
      if (lower.contains('shopee') ||
          lower.contains('lazada') ||
          lower.contains('tiktok') ||
          lower.contains('áo') ||
          lower.contains('quần') ||
          lower.contains('giày') ||
          lower.contains('son') ||
          lower.contains('mỹ phẩm')) {
        return [
          'Chốt đơn "$itemTitle" ($formattedAmount) lúc nửa tỉnh nửa mê đúng không $payerName? Tủ đồ thì chật mà hạn mức ngày giờ chỉ còn $formattedSafe.',
          'Lại săn sale "$itemTitle" mất $formattedAmount! Mua vì rẻ hay mua vì nghiện cảm giác bóc hàng vậy $payerName? Quỹ chỉ còn trụ được $predictedRunwayDays ngày.',
          'Rước "$itemTitle" về với giá $formattedAmount. Đồ mới thì đẹp đấy nhưng cuối tháng $payerName mặc đồ đẹp ngồi ăn mì tôm nhé.',
          'Tay $payerName lướt giỏ hàng chốt "$itemTitle" ($formattedAmount) mượt thật, kéo tụt hạn mức hôm nay xuống còn $formattedSafe luôn.',
        ];
      }
      return [
        'Đốt $formattedAmount vào "$itemTitle" nhanh như chớp! Niềm vui ngắn hạn của $payerName vừa lấy đi một khúc đường băng, giờ chỉ còn $predictedRunwayDays ngày sống khỏe.',
        'Giải trí kiểu "$itemTitle" ($formattedAmount) xong là ví $payerName bước vào chế độ sinh tồn khắc nghiệt. Hôm nay chỉ còn tiêu được $formattedSafe.',
        'Vừa quẹt $formattedAmount cho "$itemTitle". Cuộc vui nào cũng có giá của nó, và cái giá hiện tại là hạn mức ngày còn đúng $formattedSafe.',
        'Chơi hết mình với "$itemTitle" (-$formattedAmount), đến tuần cuối tháng ví hết tiền thì $payerName đừng hỏi tại sao nhé!',
      ];
    }

    if (category == ExpenseCategory.foodAndDrink) {
      if (amountVnd >= 100000 ||
          lower.contains('lẩu') ||
          lower.contains('nướng') ||
          lower.contains('buffet') ||
          lower.contains('sushi') ||
          lower.contains('pizza')) {
        return [
          'Một bữa "$itemTitle" ngốn luôn $formattedAmount! Ăn một bữa sướng cái miệng mà $payerName làm thủng luôn hạn mức ngày (còn $formattedSafe).',
          'Đại tiệc "$itemTitle" giá $formattedAmount! Hôm nay $payerName ăn như rồng cuốn, ngày mai nhìn số dư còn $predictedRunwayDays ngày sống sót mà rớt nước mắt.',
          'Chi hẳn $formattedAmount cho "$itemTitle". Dạ dày $payerName đang rất hạnh phúc nhưng chiếc ví thì vừa gửi đơn xin nghỉ việc.',
          'Bữa "$itemTitle" ($formattedAmount) này chất lượng đấy, chỉ tiếc là nó cuốn bay hạn mức hôm nay của $payerName về mức $formattedSafe.',
        ];
      }
      if (amountVnd <= 35000) {
        return [
          'Bữa "$itemTitle" $formattedAmount khá biết điều đấy $payerName! Giữ phong độ bình dân này thì vẫn còn dư $formattedSafe cho hôm nay.',
          'Ghi nhận "$itemTitle" giá hạt dẻ $formattedAmount. Lâu lâu mới thấy $payerName tiêu một khoản hợp lý, đường băng vẫn giữ được $predictedRunwayDays ngày.',
          'Ăn "$itemTitle" hết $formattedAmount — chuẩn bài sinh viên tiết kiệm! Hạn mức an toàn hôm nay của $payerName vẫn còn $formattedSafe.',
          'Khoản "$itemTitle" ($formattedAmount) gọn nhẹ, chưa làm đau ví. Nhưng $payerName đừng lấy cớ ăn rẻ rồi lát lại tự thưởng ly trà sữa 60k nhé!',
        ];
      }
      return [
        'Vừa nạp năng lượng bằng "$itemTitle" hết $formattedAmount. Tốc độ ăn uống của $payerName rất đều đặn, hạn mức hôm nay còn lại $formattedSafe.',
        'Đã trừ $formattedAmount cho món "$itemTitle". Bụng $payerName no rồi thì nhớ khóa app ngân hàng lại nhé, hôm nay chỉ còn được tiêu $formattedSafe thôi.',
        'Món "$itemTitle" ($formattedAmount) đã lên sổ. Với nhịp độ quẹt thẻ này của $payerName, quỹ tháng sẽ cầm cự được khoảng $predictedRunwayDays ngày nữa.',
        'Lại $formattedAmount ra đi vì "$itemTitle". Ăn uống là chính đáng nhưng $payerName nhớ nhìn con số $formattedSafe còn lại của ngày hôm nay nhé.',
        'Chi $formattedAmount cho "$itemTitle" — một pha giải cứu cái bụng đói của $payerName, đổi lại Pin ví hôm nay hạ xuống mức $formattedSafe.',
      ];
    }

    // ExpenseCategory.other or fallback with multiple distinct variants
    return [
      'Khoản "$itemTitle" ($formattedAmount) từ đâu rơi xuống thế $payerName? Hạn mức chi tiêu hôm nay bị cắt gọn còn $formattedSafe.',
      'Đã ghi sổ "$itemTitle" (-$formattedAmount). Những khoản phát sinh không tên thế này chính là thủ phạm làm ví $payerName bốc hơi nhanh nhất!',
      'Vừa bay $formattedAmount cho "$itemTitle". Đường băng tài chính của $payerName hiện còn $predictedRunwayDays ngày, tiêu pha có phanh lại nhé.',
      'Thêm một giao dịch "$itemTitle" trị giá $formattedAmount của $payerName. Số tiền an toàn được phép tiêu trong hôm nay còn $formattedSafe.',
      'Quẹt $formattedAmount cho "$itemTitle" không chớp mắt! Nhắc nhẹ $payerName là hạn mức ngày chỉ còn đúng $formattedSafe thôi.',
    ];
  }

  static List<String> _buildCoachPool({
    required String lower,
    required String itemTitle,
    required String formattedAmount,
    required String formattedSafe,
    required int amountVnd,
    required ExpenseCategory category,
    required int remainingDailySafeVnd,
    required int predictedRunwayDays,
    required String payerName,
  }) {
    final String runwayNote = predictedRunwayDays <= 10
        ? 'Lưu ý: Quỹ dự kiến chỉ còn đủ cho $predictedRunwayDays ngày, bạn nên ưu tiên các khoản thiết yếu.'
        : 'Đường băng tài chính hiện duy trì tốt ở mức $predictedRunwayDays ngày.';

    if (category == ExpenseCategory.bobaAndCafe) {
      return [
        'Đã ghi nhận "$itemTitle" ($formattedAmount) cho $payerName. Nếu giảm bớt 2 buổi đồ uống ngoài quán mỗi tuần, bạn có thể để dành thêm khoảng 400.000đ/tháng. $runwayNote',
        'Khoản "$itemTitle" ($formattedAmount) khiến hạn mức hôm nay còn $formattedSafe. Gợi ý nhỏ: tự pha cà phê hoặc trà tại phòng sẽ tiết kiệm tới 70% chi phí đồ uống.',
        '$payerName vừa chi $formattedAmount cho "$itemTitle". Bạn vẫn còn $formattedSafe trong hạn mức ngày, nhưng hãy đặt giới hạn tối đa 2–3 lần uống hàng quán mỗi tuần nhé.',
        'Đã hạch toán "$itemTitle" ($formattedAmount). Những khoản đồ uống nhỏ lẻ thường chiếm tới 15% ngân sách sinh viên nếu không theo dõi sát. $runwayNote',
        'Ghi sổ "$itemTitle" (-$formattedAmount). Để cân bằng lại ngân sách hôm nay (còn $formattedSafe), $payerName nên ưu tiên tự nấu bữa tối tại nhà.',
      ];
    }

    if (category == ExpenseCategory.dormAndUtilities) {
      return [
        'Khoản chi cố định "$itemTitle" ($formattedAmount) đã được lưu. Bạn có thể chuyển sang tab Chia Tiền QR để phân bổ đều và thu lại phần của các bạn cùng phòng.',
        'Đã cập nhật "$itemTitle" ($formattedAmount) do $payerName ứng trước. Việc tất toán sớm các hóa đơn sinh hoạt giúp nhóm kiểm soát chính xác quỹ khả dụng còn lại.',
        'Ghi nhận "$itemTitle" ($formattedAmount). Mẹo tiết kiệm cho phòng trọ: hẹn giờ tắt bình nóng lạnh và điều hòa giúp giảm 15–20% hóa đơn điện mỗi tháng.',
        'Khoản "$itemTitle" ($formattedAmount) đã được đưa vào sổ chung. Hạn mức chi tiêu cá nhân hôm nay của bạn hiện còn $formattedSafe. $runwayNote',
      ];
    }

    if (category == ExpenseCategory.transport) {
      return [
        'Đã lưu chi phí di chuyển "$itemTitle" ($formattedAmount) của $payerName. Hạn mức trong ngày còn lại $formattedSafe. $runwayNote',
        'Khoản "$itemTitle" ($formattedAmount) đã được tính vào mục Di chuyển. Nếu quãng đường dưới 2km hoặc tiện tuyến, kết hợp xe buýt/đi bộ sẽ giúp bạn dư thêm một khoản đáng kể.',
        'Ghi nhận $formattedAmount cho "$itemTitle". Bạn có thể tận dụng các gói hội viên đặt xe hoặc đi chung cùng bạn học để tối ưu chi phí đi lại hàng tuần.',
        'Đã trừ $formattedAmount tiền "$itemTitle". Ngân sách an toàn hôm nay của $payerName còn $formattedSafe, hoàn toàn nằm trong tầm kiểm soát.',
      ];
    }

    if (category == ExpenseCategory.entertainment) {
      return [
        'Khoản giải trí & mua sắm "$itemTitle" ($formattedAmount) đã được ghi nhận. Quy tắc 24 giờ (chờ 1 ngày trước khi thanh toán đồ không thiết yếu) sẽ giúp $payerName tránh mua sắm ngẫu hứng.',
        '$payerName vừa chi $formattedAmount cho "$itemTitle", hạn mức ngày còn $formattedSafe. Hãy cân đối giảm nhẹ các khoản ăn vặt trong 2 ngày tới để bù lại nhé.',
        'Đã lưu "$itemTitle" ($formattedAmount). Trong quy tắc ngân sách 50/30/20, nhóm Giải trí & Mua sắm nên được giữ dưới 20% tổng chi tiêu tháng. $runwayNote',
        'Hạch toán "$itemTitle" (-$formattedAmount). Niềm vui tinh thần rất cần thiết, miễn là bạn giữ phần chi tiêu còn lại hôm nay trong khung $formattedSafe.',
      ];
    }

    if (category == ExpenseCategory.foodAndDrink) {
      if (amountVnd >= 90000) {
        return [
          'Bữa ăn "$itemTitle" ($formattedAmount) cao hơn mức trung bình thường ngày của sinh viên. $payerName nên ưu tiên các bữa tự nấu hoặc cơm suất nhẹ nhàng vào ngày mai để cân bằng lại nhé.',
          'Đã ghi nhận "$itemTitle" ($formattedAmount). Vì khoản ăn uống này khá lớn, hạn mức an toàn hôm nay còn $formattedSafe. $runwayNote',
          'Khoản "$itemTitle" ($formattedAmount) đã lên sổ. Những bữa ăn tụ tập rất vui, bạn chỉ cần siết nhẹ chi tiêu vặt trong vài ngày tới là quỹ tháng vẫn đúng kế hoạch.',
        ];
      }
      return [
        'Bữa ăn "$itemTitle" ($formattedAmount) của $payerName rất hợp lý. Bạn vẫn còn $formattedSafe trong hạn mức an toàn của ngày hôm nay.',
        'Đã lưu "$itemTitle" ($formattedAmount) vào nhóm Ăn uống. Duy trì mức chi phí bữa ăn ổn định như hiện tại giúp đường băng tài chính giữ vững $predictedRunwayDays ngày.',
        'Ghi nhận "$itemTitle" ($formattedAmount). Dinh dưỡng đầy đủ với chi phí vừa phải là cách thông minh nhất để bảo vệ ngân sách tháng của $payerName.',
        'Khoản "$itemTitle" (-$formattedAmount) nằm gọn trong kế hoạch chi tiêu ngày. Hạn mức còn lại hôm nay của bạn là $formattedSafe.',
        'Đã hạch toán "$itemTitle" ($formattedAmount) cho $payerName. Nhịp độ chi tiêu ăn uống hôm nay đang rất cân đối. $runwayNote',
      ];
    }

    return [
      'Đã ghi nhận khoản "$itemTitle" ($formattedAmount) của $payerName. Hạn mức chi tiêu an toàn trong hôm nay còn lại $formattedSafe.',
      'Khoản phát sinh "$itemTitle" ($formattedAmount) đã được cập nhật vào sổ. $runwayNote',
      'Đã lưu "$itemTitle" (-$formattedAmount). Bạn nên rà soát lại nhóm Chi tiêu khác vào cuối tuần để nhận diện các khoản rò rỉ tài chính nhỏ.',
      'Hạch toán thành công "$itemTitle" ($formattedAmount) cho $payerName. Số dư được phép tiêu thêm hôm nay mà không lẹm vào quỹ tháng là $formattedSafe.',
    ];
  }

  /// Calls a live zero-config Cloud LLM endpoint to generate a bespoke, unique
  /// Savage Roast and Coach Advice for the exact transaction context.
  /// Falls back gracefully to null if offline or rate-limited.
  static Future<({String savage, String coach})?> fetchLiveAiResponses({
    required String itemTitle,
    required int amountVnd,
    required ExpenseCategory category,
    required int remainingDailySafeVnd,
    required int predictedRunwayDays,
    required String payerName,
  }) async {
    try {
      final formattedAmount = formatVnd(amountVnd);
      final formattedSafe = formatVnd(remainingDailySafeVnd);
      final prompt = '''
Bạn là trợ lý tài chính Gen Z Việt Nam tên SavageBot. Người dùng "$payerName" vừa chi tiêu món "$itemTitle" hết $formattedAmount (Danh mục: ${category.labelVi}).
Hạn mức tiêu thêm hôm nay còn: $formattedSafe. Số ngày sống khỏe còn lại trong tháng: $predictedRunwayDays ngày.
Hãy viết 2 câu phản hồi ngắn gọn (mỗi câu 25-45 từ, tiếng Việt tự nhiên, KHÔNG dùng icon/emoji, không lặp lại cấu trúc cũ, bám sát tên món "$itemTitle" và số tiền $formattedAmount):
1. "savage": giọng Mỏ Hỗn hài hước, cà khịa thông minh kiểu bạn thân sinh viên.
2. "coach": giọng Quân Sư tài chính điềm tĩnh, phân tích thực tế và đưa mẹo cụ thể cho món "$itemTitle".
Chỉ trả về đúng JSON hợp lệ theo mẫu: {"savage": "...", "coach": "..."}
''';

      final response = await http
          .post(
            Uri.parse('https://text.pollinations.ai/openai'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'openai',
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'Bạn chỉ trả về JSON hợp lệ {"savage":"...","coach":"..."} bằng tiếng Việt, không markdown, không emoji.',
                },
                {'role': 'user', 'content': prompt},
              ],
              'temperature': 0.9,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final String? content =
            decoded['choices']?[0]?['message']?['content'] as String?;
        if (content != null && content.isNotEmpty) {
          final startIdx = content.indexOf('{');
          final endIdx = content.lastIndexOf('}');
          if (startIdx != -1 && endIdx > startIdx) {
            final jsonMap = jsonDecode(content.substring(startIdx, endIdx + 1))
                as Map<String, dynamic>;
            final savage = (jsonMap['savage'] as String?)?.trim();
            final coach = (jsonMap['coach'] as String?)?.trim();
            if (savage != null &&
                savage.isNotEmpty &&
                coach != null &&
                coach.isNotEmpty) {
              return (savage: savage, coach: coach);
            }
          }
        }
      }
    } catch (_) {
      // Offline or timeout: keep the instant on-device multi-variant response
    }
    return null;
  }
}
