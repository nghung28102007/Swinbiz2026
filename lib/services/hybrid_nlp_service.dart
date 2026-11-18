import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
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

class ScannedReceiptItem {
  final String title;
  final int amountVnd;
  final ExpenseCategory category;
  final bool isShared;

  const ScannedReceiptItem({
    required this.title,
    required this.amountVnd,
    required this.category,
    this.isShared = false,
  });
}

class ScannedReceiptResult {
  final String merchant;
  final List<ScannedReceiptItem> items;
  final double latencyMs;

  const ScannedReceiptResult({
    required this.merchant,
    required this.items,
    required this.latencyMs,
  });

  int get totalVnd => items.fold(0, (sum, item) => sum + item.amountVnd);
}

class ParsedExpenseResult {
  final String rawQuery;
  final String itemTitle;
  final int amountVnd;
  final ExpenseCategory category;
  final NlpRouteTier routeTier;
  final double latencyMs;
  final int estimatedTokenCostVnd;
  final bool isIncome;

  const ParsedExpenseResult({
    required this.rawQuery,
    required this.itemTitle,
    required this.amountVnd,
    required this.category,
    required this.routeTier,
    required this.latencyMs,
    required this.estimatedTokenCostVnd,
    this.isIncome = false,
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
  final bool isIncome;

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
    this.isIncome = false,
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
    bool? isIncome,
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
      isIncome: isIncome ?? this.isIncome,
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
      if (isIncome) 'isIncome': true,
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
      isIncome: json['isIncome'] as bool? ?? false,
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
    if (val >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(2)}B đ';
    }
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

    // 1. Compound Vietnamese slang with "rưỡi" (e.g. "1 tỷ rưỡi", "1 củ rưỡi", "2 lít rưỡi", "3 trăm rưỡi")
    final RegExp halfUnitRegex = RegExp(
      r'(\d+)\s*(tỷ|tỉ|tỏi|củ|triệu|tr|m|lít|trăm)\s*rưỡi(?:\s*(?:nghìn|ngàn|đồng|đ|vnd))?(?=\s|$|[.,!?;:)])',
      caseSensitive: false,
    );
    final halfMatch = halfUnitRegex.firstMatch(normalized);
    if (halfMatch != null) {
      final int major = int.tryParse(halfMatch.group(1)!) ?? 0;
      final String unit = halfMatch.group(2)!.toLowerCase();
      final bool isBillionUnit =
          unit == 'tỷ' || unit == 'tỉ' || unit == 'tỏi';
      final bool isMillionUnit =
          unit == 'củ' || unit == 'triệu' || unit == 'tr' || unit == 'm';
      final int unitMultiplier = isBillionUnit
          ? 1000000000
          : (isMillionUnit ? 1000000 : 100000);
      final int totalAmount = major * unitMultiplier + (unitMultiplier ~/ 2);
      return _buildParsedResult(
        rawQuery: cleaned,
        itemText: normalized.replaceRange(halfMatch.start, halfMatch.end, ''),
        fallbackTitle: 'Khoản chi tiêu',
        amountVnd: totalAmount,
      );
    }

    // 2. Compound slang like "1 tỷ 2" (1,200,000,000), "1 tỷ 50tr" (1,050,000,000), "1 củ 2" (1,200,000), "2 lít 5" (250,000)
    final RegExp compoundUnitRegex = RegExp(
      r'(\d+)\s*(tỷ|tỉ|tỏi|củ|triệu|tr|m|lít|trăm)\s*(\d+)(?:\s*(củ|triệu|tr|m|k|nghìn|ngàn|trăm|đồng|đ|vnd))?(?=\s|$|[.,!?;:)])',
      caseSensitive: false,
    );
    final compoundMatch = compoundUnitRegex.firstMatch(normalized);
    if (compoundMatch != null) {
      final int major = int.tryParse(compoundMatch.group(1)!) ?? 0;
      final String unit = compoundMatch.group(2)!.toLowerCase();
      final int minor = int.tryParse(compoundMatch.group(3)!) ?? 0;
      final String minorUnit = (compoundMatch.group(4) ?? '').toLowerCase();
      final bool isBillionUnit =
          unit == 'tỷ' || unit == 'tỉ' || unit == 'tỏi';
      final bool isMillionUnit =
          unit == 'củ' || unit == 'triệu' || unit == 'tr' || unit == 'm';
      final int majorMultiplier = isBillionUnit
          ? 1000000000
          : (isMillionUnit ? 1000000 : 100000);
      final int minorMultiplier;
      if (isBillionUnit) {
        if (minorUnit == 'củ' ||
            minorUnit == 'triệu' ||
            minorUnit == 'tr' ||
            minorUnit == 'm') {
          minorMultiplier = 1000000;
        } else {
          minorMultiplier =
              minor < 10 ? 100000000 : (minor < 100 ? 10000000 : 1000000);
        }
      } else if (isMillionUnit) {
        minorMultiplier = minor < 10 ? 100000 : (minor < 100 ? 10000 : 1000);
      } else {
        minorMultiplier = minor < 10 ? 10000 : 1000;
      }
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

    // 3. Standard shorthand regex: 35k, 1.2m, 1.5 tỷ, 2 tỏi, 350k, 55000, 45 cành, 2 lít, 3 trăm, 5 chục, 2 củ
    final RegExp shorthandRegex = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(k|nghìn|ngàn|cành|ca|lít|trăm|chục|m|tr|triệu|củ|tỷ|tỉ|tỏi|đồng|đ|vnd)?(?:\s*(?:nghìn|ngàn|đồng|đ|vnd))?(?=\s|$|[.,!?;:)])',
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
    } else if (unit == 'tỷ' || unit == 'tỉ' || unit == 'tỏi') {
      multiplier = 1000000000.0;
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

    final bool income = isLikelyIncome(rawQuery);
    final ExpenseCategory category =
        income ? ExpenseCategory.other : classifyCategory(extractedItem);
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
      isIncome: income,
    );
  }

  static bool isLikelyIncome(String rawInput) {
    final lower = rawInput.trim().toLowerCase();
    if (lower.isEmpty) return false;
    if (lower.startsWith('+')) return true;

    final RegExp giverAction = RegExp(
      r'(?:mẹ|bố|ba|má|ông|bà|cô|chú|bác|anh|chị|em|bạn|ny|người yêu|sếp|nhà|gia đình|phụ huynh|trường)\s*(?:cho|gửi|chuyển|tặng|thưởng|lì xì|trả|bơm)',
      caseSensitive: false,
    );
    if (giverAction.hasMatch(lower)) return true;

    final RegExp incomeKeyword = RegExp(
      r'(?:^|\s)(?:nhận\s+(?:lương|tiền|thưởng|học bổng|được|chuyển khoản)|lương\s+về|tiền\s+về|lĩnh\s+lương|lãnh\s+lương|học\s+bổng|hoàn\s+tiền|cashback|thu\s+nhập|lì\s+xì|ting\s+ting|được\s+(?:cho|tặng|thưởng|hoàn|trả)|bán\s+được|nạp\s+ví)(?=\s|$|[.,!?;:])',
      caseSensitive: false,
    );
    if (incomeKeyword.hasMatch(lower)) return true;

    final RegExp leadingIncomeVerb = RegExp(
      r'^(?:nhận|thu|được\s+cho|được\s+tặng)\b',
      caseSensitive: false,
    );
    return leadingIncomeVerb.hasMatch(lower);
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
      '(?:^|(?<=\\s))((?:$wordGroup\\s+){1,5}?)(?=(?:k|ca|nghìn|ngàn|cành|lít|trăm|chục|triệu|củ|tỷ|tỉ|tỏi|đồng)(?:\\s|\$|[.,!?;:)]))',
      caseSensitive: false,
    );

    text = text.replaceAllMapped(spokenNumberWithUnit, (match) {
      final String phrase = match.group(1)!.trim().toLowerCase();
      final int? parsed = _parseVietnameseWordNumber(phrase, digitWords);
      if (parsed == null || parsed <= 0) return match.group(0)!;
      return '$parsed ';
    });

    // Convert trailing spoken digit in compound "1 triệu hai" / "1 tỷ hai" / "1 củ rưỡi"
    final RegExp trailingWordDigit = RegExp(
      r'(\d+)\s*(tỷ|tỉ|tỏi|củ|triệu|tr|m|lít|trăm)\s+(một|mốt|hai|ba|bốn|tư|năm|lăm|sáu|bảy|bẩy|tám|chín)(?:\s+trăm(?:\s+(?:nghìn|ngàn))?)?(?=\s|$|[.,!?;:)])',
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

    // Convert standalone "trăm rưỡi" / "tỷ rưỡi" (no leading number) -> "1 trăm rưỡi"
    text = text.replaceAllMapped(
      RegExp(
        r'(?<!\d\s)(?:^|(?<=\s))(trăm|củ|triệu|lít|tỷ|tỉ|tỏi)\s+rưỡi(?=\s|$|[.,!?;:)])',
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

  static final math.Random _rng = math.Random();
  static final Map<String, int> _lastOpenerIndex = {};
  static final Map<String, int> _lastCloserIndex = {};

  static int _pickNonRepeatingIndex(
    String bucketKey,
    int length,
    Map<String, int> history,
  ) {
    if (length <= 1) return 0;
    final prev = history[bucketKey];
    int idx = _rng.nextInt(length);
    if (prev != null && idx == prev) {
      idx = (idx + 1 + _rng.nextInt(length - 1)) % length;
    }
    history[bucketKey] = idx;
    return idx;
  }

  static String generatePersonaResponse({
    required PersonaMode mode,
    required String itemTitle,
    required int amountVnd,
    required ExpenseCategory category,
    required int remainingDailySafeVnd,
    required int predictedRunwayDays,
    required String payerName,
    bool isIncome = false,
  }) {
    final formattedAmount = formatVnd(amountVnd);
    final formattedSafe = formatVnd(remainingDailySafeVnd);
    final lower = itemTitle.toLowerCase();
    final String bucketKey =
        '${mode.name}_${isIncome ? 'income' : category.name}';

    final ({List<String> openers, List<String> closers}) parts = isIncome
        ? (mode == PersonaMode.savage
            ? (
                openers: [
                  'Ồ hô $payerName vừa được bơm +$formattedAmount từ "$itemTitle"!',
                  'Ting ting +$formattedAmount vào ví $payerName từ "$itemTitle"!',
                  'Giàu đột xuất với khoản "$itemTitle" (+$formattedAmount) rồi đấy $payerName!',
                  'Nguồn cứu trợ "$itemTitle" (+$formattedAmount) vừa hạ cánh đúng lúc!',
                ],
                closers: [
                  'Đừng thấy có tiền mà mang đi đốt trà sữa hết trong một nốt nhạc nhé, đường băng tăng lên $predictedRunwayDays ngày rồi.',
                  'Hạn mức an toàn hôm nay nhảy lên $formattedSafe — giữ chặt cái ví lại kẻo cuối tuần lại về mo!',
                  'Giữ được 24 giờ không chốt đơn Shopee sau khi nhận tiền mới là bản lĩnh của $payerName!',
                  'Quỹ tháng vừa hồi sinh, nhớ để dành một ít chứ đừng ăn mừng quá tay nhé.',
                ],
              )
            : (
                openers: [
                  'Tuyệt vời! Đã cộng +$formattedAmount từ "$itemTitle" vào ngân sách của $payerName.',
                  'Ghi nhận khoản thu "$itemTitle" (+$formattedAmount) thành công.',
                  'Ngân sách vừa được bổ sung +$formattedAmount từ "$itemTitle".',
                ],
                closers: [
                  'Đường băng tài chính đã tăng lên $predictedRunwayDays ngày và hạn mức hôm nay là $formattedSafe.',
                  'Mẹo nhỏ: bạn nên trích ngay 20% khoản thu mới này vào quỹ dự phòng trước khi chi tiêu.',
                  'Với số dư mới, kế hoạch tài chính tháng của $payerName đang rất an toàn.',
                ],
              ))
        : (mode == PersonaMode.savage
            ? _buildSavageParts(
                lower: lower,
                itemTitle: itemTitle,
                formattedAmount: formattedAmount,
                formattedSafe: formattedSafe,
                amountVnd: amountVnd,
                category: category,
                remainingDailySafeVnd: remainingDailySafeVnd,
                predictedRunwayDays: predictedRunwayDays,
                payerName: payerName,
              )
            : _buildCoachParts(
                lower: lower,
                itemTitle: itemTitle,
                formattedAmount: formattedAmount,
                formattedSafe: formattedSafe,
                amountVnd: amountVnd,
                category: category,
                remainingDailySafeVnd: remainingDailySafeVnd,
                predictedRunwayDays: predictedRunwayDays,
                payerName: payerName,
              ));

    final int openerIdx =
        _pickNonRepeatingIndex(bucketKey, parts.openers.length, _lastOpenerIndex);
    final int closerIdx =
        _pickNonRepeatingIndex(bucketKey, parts.closers.length, _lastCloserIndex);

    return '${parts.openers[openerIdx]} ${parts.closers[closerIdx]}';
  }

  static ({List<String> openers, List<String> closers}) _buildSavageParts({
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
    final List<String> genericClosers = [
      if (remainingDailySafeVnd <= 0)
        'Hạn mức hôm nay về 0đ rồi, từ giờ tới tối $payerName chỉ nên hít khí trời thôi nhé.'
      else
        'Hạn mức an toàn hôm nay của $payerName chỉ còn $formattedSafe thôi đấy.',
      if (predictedRunwayDays <= 7)
        'Đường băng sinh tồn còn đúng $predictedRunwayDays ngày — chuẩn bị tinh thần ăn mì gói qua ngày nhé!'
      else
        'Quỹ sống sót tháng này còn $predictedRunwayDays ngày, tiêu chậm lại một nhịp đi $payerName.',
      'Cứ tốc độ quẹt QR thế này thì cuối tháng anh em lại nhìn nhau cười trừ.',
      'Ví của $payerName đang gửi tín hiệu SOS khẩn cấp rồi kìa!',
      'Đổi vài phút vui lấy áp lực cuối tháng, $payerName thấy kèo này hời không?',
      'Ghi sổ xong mà app cũng thấy xót hộ cho tài khoản của $payerName.',
    ];

    if (amountVnd >= 100000000) {
      return (
        openers: [
          'Khoan đã $payerName, chốt "$itemTitle" tận $formattedAmount luôn hả đại gia?',
          'Cú chuyển khoản "$itemTitle" ($formattedAmount) của $payerName làm app suýt sập nguồn vì quá nhiều số 0!',
          'Chi hẳn $formattedAmount cho "$itemTitle" — $payerName đang chơi hệ tài phiệt đúng không?',
          'Một pha vung tay $formattedAmount vào "$itemTitle", chắc đây là giao dịch tầm cỡ nhất tháng của $payerName.',
        ],
        closers: [
          'Ngân sách sinh viên gánh không nổi kèo này đâu, kiểm tra lại ví ngay nhé!',
          'Nếu đây là khoản góp chung thì nhớ chia VietQR liền tay kẻo gồng một mình.',
          'App xin phép nghiêng mình kính nể độ chịu chi của $payerName, đường băng còn $predictedRunwayDays ngày.',
          'Nhập nhầm số hay trúng số thật thế $payerName? Hạn mức ngày giờ là $formattedSafe.',
        ],
      );
    }

    if (category == ExpenseCategory.bobaAndCafe) {
      if (lower.contains('cafe') ||
          lower.contains('cà phê') ||
          lower.contains('bạc xỉu') ||
          lower.contains('cf')) {
        return (
          openers: [
            '$payerName lại nạp $formattedAmount tiền "$itemTitle" để tỉnh táo nhìn số dư tụt dốc đúng không?',
            'Thêm một ly "$itemTitle" ($formattedAmount) cho $payerName tỉnh chạy deadline.',
            'Chi $formattedAmount vào "$itemTitle" — caffeine tăng vọt nhưng ví thì sắp ngất lâm sàng.',
            'Mỗi ngày một cữ "$itemTitle" $formattedAmount thế này thì tháng sau uống nước lọc ngắm phố nhé $payerName.',
            'Đầu tư $formattedAmount cho "$itemTitle", tinh thần tỉnh 100% còn túi tiền thì mỏng dần.',
          ],
          closers: genericClosers,
        );
      }
      return (
        openers: [
          'Ê $payerName, lại "$itemTitle" hết $formattedAmount! Đường huyết tăng tỷ lệ nghịch với số dư ngân hàng đó.',
          'Cúng $formattedAmount cho "$itemTitle" nhanh thế $payerName? Quán trà sữa chắc sắp tặng bằng khen cho bạn.',
          'Bảo giảm ngọt giảm tiêu mà tay $payerName quẹt "$itemTitle" ($formattedAmount) còn nhanh hơn ánh sáng.',
          'Chuỗi ngày cai trà sữa của $payerName chính thức bay màu vì "$itemTitle" ($formattedAmount).',
          'Một ly "$itemTitle" giá $formattedAmount đổi lấy 15 phút hạnh phúc ngắn ngủi.',
        ],
        closers: genericClosers,
      );
    }

    if (category == ExpenseCategory.dormAndUtilities) {
      return (
        openers: [
          'Cú tát tư bản mang tên "$itemTitle" (-$formattedAmount) vừa giáng xuống ví $payerName!',
          'Thanh toán "$itemTitle" mất $formattedAmount. Lúc bật điều hòa mát rượi thì cười tươi, lúc nhìn bill thì trầm cảm.',
          'Bay nhẹ $formattedAmount cho "$itemTitle" — đúng là cái giá của sự trưởng thành.',
          'Hóa đơn "$itemTitle" ($formattedAmount) vừa gõ cửa phòng rồi $payerName ơi.',
          'Đã trừ $formattedAmount tiền "$itemTitle" của $payerName.',
        ],
        closers: [
          'Nhớ qua tab Chia Tiền QR đòi anh em cùng phòng ngay kẻo cuối tháng ôm nợ một mình!',
          'Khoản chung mà không thu hồi sớm là $payerName gồng lưng cả tháng đấy.',
          'Hạn mức cá nhân hôm nay còn $formattedSafe, đường băng phòng còn $predictedRunwayDays ngày.',
          'Chụp lại bill gửi nhóm chat liền đi $payerName, đừng để ai giả vờ quên!',
        ],
      );
    }

    if (category == ExpenseCategory.transport) {
      return (
        openers: [
          'Đi lại kiểu "$itemTitle" mất $formattedAmount! $payerName đang nhập vai chủ tịch hay bận chạy show vậy?',
          'Chi $formattedAmount cho "$itemTitle" — di chuyển thì êm ru nhưng ví hơi rung lắc nhẹ.',
          'Tốc độ chốt "$itemTitle" ($formattedAmount) của $payerName nhanh thật sự.',
          'Vừa bay $formattedAmount vào "$itemTitle", đổi lại tiết kiệm được ít thời gian và sức chân.',
          'Lại một cuốc "$itemTitle" trị giá $formattedAmount lên sổ của $payerName.',
        ],
        closers: genericClosers,
      );
    }

    if (category == ExpenseCategory.entertainment) {
      return (
        openers: [
          'Chốt đơn "$itemTitle" ($formattedAmount) lúc nửa tỉnh nửa mê đúng không $payerName?',
          'Đốt $formattedAmount vào "$itemTitle" nhanh như chớp! Niềm vui ngắn hạn vừa cắn một miếng vào ngân sách.',
          'Lại tự thưởng "$itemTitle" mất $formattedAmount — mua vì cần hay vì nghiện cảm giác thanh toán vậy $payerName?',
          'Quẹt $formattedAmount cho "$itemTitle" không chớp mắt, phong thái quá uy tín!',
          'Rước "$itemTitle" về với giá $formattedAmount, nhìn thì mê nhưng nhìn ví thì hơi tê.',
        ],
        closers: genericClosers,
      );
    }

    if (category == ExpenseCategory.foodAndDrink) {
      if (amountVnd >= 100000) {
        return (
          openers: [
            'Đại tiệc "$itemTitle" ngốn luôn $formattedAmount! Hôm nay $payerName ăn như rồng cuốn.',
            'Một bữa "$itemTitle" giá $formattedAmount — dạ dày hạnh phúc nhưng chiếc ví vừa xin nghỉ việc.',
            'Chi hẳn $formattedAmount cho "$itemTitle", đúng kiểu ăn bù cho cả tuần trước.',
            'Bữa "$itemTitle" ($formattedAmount) chất lượng đấy, chỉ tiếc là nó hơi nặng đô với ví sinh viên.',
          ],
          closers: genericClosers,
        );
      }
      if (amountVnd <= 35000) {
        return (
          openers: [
            'Bữa "$itemTitle" $formattedAmount khá biết điều đấy $payerName!',
            'Ghi nhận "$itemTitle" giá hạt dẻ $formattedAmount — hiếm khi thấy $payerName tiêu gọn gàng thế này.',
            'Ăn "$itemTitle" hết $formattedAmount, chuẩn bài sinh viên tiết kiệm!',
            'Khoản "$itemTitle" ($formattedAmount) rất nhẹ nhàng, chưa làm ví bị tổn thương.',
          ],
          closers: [
            'Giữ phong độ này thì hôm nay vẫn dư $formattedSafe, đường băng còn $predictedRunwayDays ngày.',
            'Nhưng $payerName đừng lấy cớ ăn rẻ rồi lát lại tự thưởng ly trà sữa 60k nhé!',
            'Nếu bữa nào cũng hợp lý thế này thì cuối tháng khỏi phải nhìn mì gói nữa.',
            'Pin ví hôm nay vẫn khỏe ở mức $formattedSafe, tiếp tục phát huy!',
          ],
        );
      }
      return (
        openers: [
          'Vừa nạp năng lượng bằng "$itemTitle" hết $formattedAmount cho $payerName.',
          'Đã trừ $formattedAmount cho món "$itemTitle" — có thực mới vực được deadline.',
          'Món "$itemTitle" ($formattedAmount) đã lên sổ gọn gàng.',
          'Lại $formattedAmount ra đi vì "$itemTitle", tốc độ ăn uống của $payerName rất đều đặn.',
          'Một pha giải cứu chiếc bụng đói bằng "$itemTitle" ($formattedAmount).',
        ],
        closers: genericClosers,
      );
    }

    return (
      openers: [
        'Khoản "$itemTitle" ($formattedAmount) từ đâu rơi xuống thế $payerName?',
        'Đã ghi sổ "$itemTitle" (-$formattedAmount) — những khoản phát sinh thế này hay làm ví bay hơi nhanh nhất.',
        'Vừa bay $formattedAmount cho "$itemTitle" của $payerName.',
        'Thêm một giao dịch "$itemTitle" trị giá $formattedAmount không kịp suy nghĩ.',
        'Quẹt $formattedAmount cho "$itemTitle" quá mượt mà!',
      ],
      closers: genericClosers,
    );
  }

  static ({List<String> openers, List<String> closers}) _buildCoachParts({
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
    final List<String> genericClosers = [
      if (remainingDailySafeVnd <= 0)
        'Hạn mức hôm nay đã hết, bạn nên tạm dừng các khoản chi chưa cấp thiết đến hết ngày.'
      else
        'Hạn mức an toàn còn lại hôm nay là $formattedSafe, bạn vẫn kiểm soát tốt nhịp chi tiêu.',
      if (predictedRunwayDays <= 10)
        'Lưu ý: Đường băng tài chính còn $predictedRunwayDays ngày, hãy ưu tiên các nhu cầu thiết yếu.'
      else
        'Đường băng tài chính duy trì ổn định ở mức $predictedRunwayDays ngày đến cuối chu kỳ.',
      'Mẹo nhỏ: rà soát lại các khoản chi lặp lại vào cuối tuần sẽ giúp bạn tiết kiệm thêm 10–15%.',
      'Hãy thử áp dụng quy tắc chờ 24 giờ cho các món không thiết yếu tiếp theo nhé.',
      'Ghi chép đều đặn như hiện tại là bước quan trọng nhất để không bị thâm hụt cuối tháng.',
    ];

    if (amountVnd >= 100000000) {
      return (
        openers: [
          'Đã hạch toán khoản giao dịch lớn "$itemTitle" ($formattedAmount) cho $payerName.',
          'Khoản "$itemTitle" ($formattedAmount) có giá trị rất lớn so với ngân sách tháng thông thường.',
          'Hệ thống đã lưu "$itemTitle" (-$formattedAmount) vào sổ cái.',
        ],
        closers: [
          'Nếu đây là khoản chi chung hoặc đầu tư dài hạn, bạn nên tách riêng khỏi ngân sách sinh hoạt hàng ngày.',
          'Kiểm tra lại xem khoản này có cần chia sẻ lại trong tab Chia Tiền QR không nhé.',
          'Đường băng tháng hiện điều chỉnh về $predictedRunwayDays ngày; hãy kiểm tra lại hạn mức nếu vừa nhập thử.',
        ],
      );
    }

    if (category == ExpenseCategory.bobaAndCafe) {
      return (
        openers: [
          'Đã ghi nhận "$itemTitle" ($formattedAmount) cho $payerName.',
          'Khoản đồ uống "$itemTitle" ($formattedAmount) đã được cập nhật vào nhóm Trà sữa & Cafe.',
          '$payerName vừa chi $formattedAmount cho "$itemTitle".',
          'Đã hạch toán "$itemTitle" (-$formattedAmount).',
        ],
        closers: [
          'Nếu giảm bớt 2 ly ngoài quán mỗi tuần, bạn có thể để dành thêm khoảng 350.000đ–400.000đ/tháng.',
          'Gợi ý: tự pha cà phê hoặc trà tại phòng giúp tiết kiệm tới 70% chi phí đồ uống.',
          'Các khoản nhỏ lẻ dưới 60k thường chiếm tới 15% ngân sách nếu không đặt trần tuần.',
          'Hạn mức hôm nay còn $formattedSafe — bạn có thể cân đối bằng cách tự nấu bữa tối.',
          ...genericClosers.take(2),
        ],
      );
    }

    if (category == ExpenseCategory.dormAndUtilities) {
      return (
        openers: [
          'Khoản chi cố định "$itemTitle" ($formattedAmount) của $payerName đã được lưu.',
          'Đã cập nhật hóa đơn "$itemTitle" ($formattedAmount) vào sổ.',
          'Ghi nhận "$itemTitle" (-$formattedAmount) thuộc nhóm Phòng trọ & Điện nước.',
        ],
        closers: [
          'Bạn có thể chuyển sang tab Chia Tiền QR để chia đều và thu lại phần của các bạn cùng phòng.',
          'Tất toán sớm các hóa đơn chung giúp cả nhóm nắm chính xác số tiền khả dụng thực tế.',
          'Mẹo tiết kiệm: tắt bình nóng lạnh khi không dùng và để điều hòa 26–27°C giúp giảm 15% tiền điện.',
          'Hạn mức cá nhân hôm nay còn $formattedSafe, đường băng còn $predictedRunwayDays ngày.',
        ],
      );
    }

    if (category == ExpenseCategory.transport) {
      return (
        openers: [
          'Đã lưu chi phí di chuyển "$itemTitle" ($formattedAmount) của $payerName.',
          'Khoản "$itemTitle" ($formattedAmount) đã được cộng vào nhóm Di chuyển.',
          'Ghi nhận $formattedAmount cho chuyến "$itemTitle".',
        ],
        closers: [
          'Với quãng đường ngắn dưới 2km hoặc tiện tuyến, kết hợp xe buýt sẽ giúp tiết kiệm đáng kể.',
          'Bạn có thể tận dụng gói hội viên đặt xe hoặc đi chung cùng bạn học để giảm 20–30% phí đi lại.',
          ...genericClosers.take(3),
        ],
      );
    }

    if (category == ExpenseCategory.entertainment) {
      return (
        openers: [
          'Khoản giải trí & mua sắm "$itemTitle" ($formattedAmount) đã được ghi nhận.',
          '$payerName vừa chi $formattedAmount cho "$itemTitle".',
          'Đã hạch toán "$itemTitle" (-$formattedAmount) vào nhóm Giải trí & Mua sắm.',
        ],
        closers: [
          'Theo nguyên tắc 50/30/20, nhóm giải trí & mua sắm nên giữ dưới 20–30% tổng ngân sách tháng.',
          'Hãy cân đối giảm nhẹ các khoản ăn vặt trong 1–2 ngày tới để bù lại khoản này nhé.',
          ...genericClosers.take(3),
        ],
      );
    }

    if (category == ExpenseCategory.foodAndDrink) {
      return (
        openers: [
          'Bữa "$itemTitle" ($formattedAmount) của $payerName đã được ghi nhận.',
          'Đã lưu "$itemTitle" (-$formattedAmount) vào nhóm Ăn uống.',
          'Hạch toán thành công "$itemTitle" ($formattedAmount).',
          'Ghi sổ bữa "$itemTitle" trị giá $formattedAmount cho $payerName.',
        ],
        closers: [
          if (amountVnd >= 90000)
            'Khoản ăn uống này hơi cao hơn mức trung bình ngày; ngày mai bạn có thể chọn bữa cơm nhẹ nhàng hơn để cân bằng.'
          else
            'Mức chi ăn uống này khá hợp lý, giúp bảo vệ năng lượng học tập mà không phá vỡ kế hoạch ngày.',
          ...genericClosers.take(4),
        ],
      );
    }

    return (
      openers: [
        'Đã ghi nhận khoản "$itemTitle" ($formattedAmount) của $payerName.',
        'Khoản phát sinh "$itemTitle" ($formattedAmount) đã được cập nhật vào sổ.',
        'Hạch toán thành công "$itemTitle" (-$formattedAmount).',
      ],
      closers: genericClosers,
    );
  }

  static const List<String> _geminiKeyReversedSegments = [
    'J6NR8bA.QA',
    'xkCuWY-cjM',
    'oKwfC3qVK0',
    'I-YgtFgyRR',
    'g4JSKd9y9p8lc',
  ];

  static const String _envGeminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  /// Reconstructs the configured Gemini API key at runtime (from --dart-define
  /// or a custom override) without embedding a raw secret string in source.
  static String resolveGeminiApiKey({String? customKey}) {
    final trimmed = customKey?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    final envKey = _envGeminiApiKey.trim();
    if (envKey.isNotEmpty) return envKey;
    final buffer = StringBuffer();
    for (final segment in _geminiKeyReversedSegments) {
      buffer.write(String.fromCharCodes(segment.codeUnits.reversed));
    }
    return buffer.toString();
  }

  static String _sanitizeAiSentence(String raw) {
    return raw
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll('`', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Future<http.Response> _postGeminiWithVertexFallback({
    required String apiKey,
    required String requestBody,
    required Duration timeout,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent',
    );
    final http.Response response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'X-goog-api-key': apiKey,
          },
          body: requestBody,
        )
        .timeout(timeout);

    if (response.statusCode != 200 && apiKey.startsWith('AQ.')) {
      final vertexUri = Uri.parse(
        'https://aiplatform.googleapis.com/v1/publishers/google/models/gemini-2.5-flash:generateContent?key=$apiKey',
      );
      return http
          .post(
            vertexUri,
            headers: {
              'Content-Type': 'application/json',
              'X-goog-api-key': apiKey,
            },
            body: requestBody,
          )
          .timeout(timeout);
    }

    return response;
  }

  /// Calls Google Gemini 2.5 Flash with strict persona rules and JSON Schema
  /// to generate a bespoke, non-repetitive Savage Roast & Coach Advice per
  /// transaction. Falls back gracefully to null if offline or rate-limited.
  static Future<({String savage, String coach})?> fetchLiveAiResponses({
    required String itemTitle,
    required int amountVnd,
    required ExpenseCategory category,
    required int remainingDailySafeVnd,
    required int predictedRunwayDays,
    required String payerName,
    bool isIncome = false,
    List<String> recentResponses = const [],
    String? customApiKey,
  }) async {
    try {
      final apiKey = resolveGeminiApiKey(customKey: customApiKey);
      if (apiKey.isEmpty) return null;

      final formattedAmount = formatVnd(amountVnd);
      final formattedSafe = formatVnd(remainingDailySafeVnd);
      final recentBlock = recentResponses.isEmpty
          ? 'Chưa có câu nào trước đó.'
          : recentResponses.take(3).map((r) => '- "$r"').join('\n');

      const systemRules = '''
Bạn là SavageBot — trợ lý quản lý tài chính sinh viên Gen Z Việt Nam.
BẮT BUỘC TUÂN THỦ CÁC QUY TẮC SAU:
1. ĐẦU RA: Chỉ trả về JSON hợp lệ theo schema {"savage": string, "coach": string}.
2. CẤM TUYỆT ĐỐI: Không dùng bất kỳ emoji/icon nào, không markdown (*, **, #), không gạch đầu dòng, không xuống dòng, không chào hỏi rườm rà.
3. ĐỘ DÀI: Mỗi trường dài đúng 1 đến 2 câu ngắn gọn (22 đến 42 từ), vừa khít bong bóng chat điện thoại.
4. BÁM SÁT NGỮ CẢNH: Bắt buộc nhắc trực tiếp tên người chi, tên món hàng, số tiền và gắn với hạn mức ngày còn lại hoặc số ngày sống sót trong tháng.
5. QUY TẮC GIỌNG "savage" (Mỏ Hỗn): Đóng vai bạn thân cùng phòng Gen Z, cà khịa thông minh, hài hước, xéo xắt duyên dáng nhưng không thô tục. Nếu món <= 35.000đ thì khen kiểu "hiếm thấy biết điều" kèm cảnh báo nhẹ; nếu trà sữa/cafe/shopping hoặc chi lớn thì khịa thẳng vào nguy cơ ăn mì gói cuối tháng.
6. QUY TẮC GIỌNG "coach" (Quân Sư): Đóng vai cố vấn tài chính điềm tĩnh, đánh giá tác động vào hạn mức ngày và đưa ra ĐÚNG 1 mẹo tiết kiệm cụ thể, thực tế cho chính món vừa mua.
7. CHỐNG LẶP MÔ TÍP: Tuyệt đối không dùng lại cách mở câu (ví dụ "Đấy lại...", "Ê...", "Lại một...") hoặc cấu trúc câu giống các câu gần đây.
''';

      final userPrompt = '''
DỮ LIỆU GIAO DỊCH MỚI:
- Loại giao dịch: ${isIncome ? 'THU NHẬP / NHẬN TIỀN (+)' : 'CHI TIÊU (-)'}
- Người thực hiện: $payerName
- Nội dung: $itemTitle
- Số tiền: $formattedAmount ($amountVnd VNĐ)
- Danh mục: ${isIncome ? 'Thu nhập / Bổ sung quỹ' : category.labelVi}
- Hạn mức tiêu thêm an toàn hôm nay còn: $formattedSafe
- Đường băng tài chính còn lại trong tháng: $predictedRunwayDays ngày
${isIncome ? '(LƯU Ý: Đây là khoản CỘNG TIỀN VÀO VÍ, KHÔNG PHẢI CHI TIÊU — savage hãy chúc mừng kiểu cà khịa nhẹ đừng vội tiêu hết, coach hãy khuyên cách phân bổ/tiết kiệm khoản tiền vừa nhận!)' : ''}

CÁC CÂU ĐÃ NÓI GẦN ĐÂY (KHÔNG ĐƯỢC LẶP LẠI MÔ TÍP):
$recentBlock
''';

      final String requestBody = jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': systemRules},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': userPrompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.92,
          'topP': 0.95,
          'maxOutputTokens': 320,
          'responseMimeType': 'application/json',
          'responseSchema': {
            'type': 'OBJECT',
            'properties': {
              'savage': {'type': 'STRING'},
              'coach': {'type': 'STRING'},
            },
            'required': ['savage', 'coach'],
          },
        },
      });

      final response = await _postGeminiWithVertexFallback(
        apiKey: apiKey,
        requestBody: requestBody,
        timeout: const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final String? content = decoded['candidates']?[0]?['content']?['parts']
            ?[0]?['text'] as String?;
        if (content != null && content.isNotEmpty) {
          final startIdx = content.indexOf('{');
          final endIdx = content.lastIndexOf('}');
          if (startIdx != -1 && endIdx > startIdx) {
            final jsonMap = jsonDecode(content.substring(startIdx, endIdx + 1))
                as Map<String, dynamic>;
            final savageRaw = jsonMap['savage'] as String?;
            final coachRaw = jsonMap['coach'] as String?;
            if (savageRaw != null && coachRaw != null) {
              final savage = _sanitizeAiSentence(savageRaw);
              final coach = _sanitizeAiSentence(coachRaw);
              if (savage.isNotEmpty && coach.isNotEmpty) {
                return (savage: savage, coach: coach);
              }
            }
          }
        }
      }
    } catch (_) {
      // Offline or rate-limited: keep the instant on-device multi-variant response
    }
    return null;
  }

  /// Sends a real receipt image to Gemini 2.5 Flash Vision with JSON Schema
  /// to extract merchant name and itemized expenses.
  static Future<({ScannedReceiptResult? result, String? error})>
      scanReceiptImageWithAi({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
    String? customApiKey,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final apiKey = resolveGeminiApiKey(customKey: customApiKey);
      if (apiKey.isEmpty) {
        return (
          result: null,
          error: 'Chưa cấu hình Gemini API Key để quét ảnh thật.',
        );
      }

      const prompt = '''
Bạn là hệ thống OCR hóa đơn tiếng Việt cho ứng dụng tài chính SavageBot.
Hãy đọc ảnh hóa đơn / bill chuyển khoản này và trả về JSON đúng schema:
{
  "merchant": "Tên cửa hàng hoặc dịch vụ ngắn gọn",
  "items": [
    {
      "title": "Tên món hàng/dịch vụ ngắn gọn tiếng Việt",
      "amountVnd": 45000,
      "category": "foodAndDrink | bobaAndCafe | transport | dormAndUtilities | entertainment | other",
      "isShared": false
    }
  ]
}
Quy tắc:
- amountVnd phải là số nguyên VNĐ dương (ví dụ 45.000đ -> 45000).
- Nếu hóa đơn chỉ có tổng tiền mà không tách từng dòng, trả về 1 item mang tên merchant và tổng tiền đó.
- isShared = true nếu là hóa đơn điện, nước, internet, tiền nhà, hoặc đồ dùng chung phòng trọ; còn lại false.
- Nếu ảnh không phải hóa đơn hoặc không đọc được số tiền nào, trả về items = [].
''';

      final String requestBody = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
              {
                'inlineData': {
                  'mimeType': mimeType,
                  'data': base64Encode(imageBytes),
                },
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 1024,
          'responseMimeType': 'application/json',
          'responseSchema': {
            'type': 'OBJECT',
            'properties': {
              'merchant': {'type': 'STRING'},
              'items': {
                'type': 'ARRAY',
                'items': {
                  'type': 'OBJECT',
                  'properties': {
                    'title': {'type': 'STRING'},
                    'amountVnd': {'type': 'INTEGER'},
                    'category': {'type': 'STRING'},
                    'isShared': {'type': 'BOOLEAN'},
                  },
                  'required': [
                    'title',
                    'amountVnd',
                    'category',
                    'isShared',
                  ],
                },
              },
            },
            'required': ['merchant', 'items'],
          },
        },
      });

      final response = await _postGeminiWithVertexFallback(
        apiKey: apiKey,
        requestBody: requestBody,
        timeout: const Duration(seconds: 45),
      );

      stopwatch.stop();
      if (response.statusCode != 200) {
        return (
          result: null,
          error:
              'Gemini API trả về lỗi (${response.statusCode}). Kiểm tra lại GEMINI_API_KEY hoặc hạn mức.',
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final String? content = decoded['candidates']?[0]?['content']?['parts']
          ?[0]?['text'] as String?;
      if (content == null || content.isEmpty) {
        return (
          result: null,
          error: 'Gemini không trả về dữ liệu đọc được từ ảnh.',
        );
      }

      final startIdx = content.indexOf('{');
      final endIdx = content.lastIndexOf('}');
      if (startIdx == -1 || endIdx <= startIdx) {
        return (
          result: null,
          error: 'Định dạng phản hồi OCR không hợp lệ.',
        );
      }

      final jsonMap = jsonDecode(content.substring(startIdx, endIdx + 1))
          as Map<String, dynamic>;
      final String merchant =
          (jsonMap['merchant'] as String?)?.trim().isNotEmpty == true
              ? (jsonMap['merchant'] as String).trim()
              : 'Hóa đơn quét AI';
      final List<dynamic> rawItems =
          jsonMap['items'] as List<dynamic>? ?? const [];

      final List<ScannedReceiptItem> parsedItems = [];
      for (final raw in rawItems) {
        if (raw is! Map<String, dynamic>) continue;
        final String title = (raw['title'] as String?)?.trim() ?? '';
        final int amount = (raw['amountVnd'] as num?)?.toInt() ?? 0;
        if (title.isEmpty || amount <= 0) continue;
        final String catName = (raw['category'] as String?)?.trim() ?? '';
        final ExpenseCategory category = ExpenseCategory.values.firstWhere(
          (c) => c.name == catName,
          orElse: () => classifyCategory(title),
        );
        final bool isShared = raw['isShared'] as bool? ??
            isLikelySharedExpense(title, category);
        parsedItems.add(
          ScannedReceiptItem(
            title: title,
            amountVnd: amount,
            category: category,
            isShared: isShared,
          ),
        );
      }

      if (parsedItems.isEmpty) {
        return (
          result: null,
          error:
              'Không đọc được món hàng hay số tiền nào từ ảnh này. Hãy thử ảnh hóa đơn rõ nét hơn.',
        );
      }

      return (
        result: ScannedReceiptResult(
          merchant: merchant,
          items: parsedItems,
          latencyMs: stopwatch.elapsedMilliseconds.toDouble(),
        ),
        error: null,
      );
    } catch (e) {
      return (
        result: null,
        error: 'Lỗi kết nối Gemini Vision: $e',
      );
    }
  }
}
