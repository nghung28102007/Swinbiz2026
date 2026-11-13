import 'dart:convert';

class VietnamBankOption {
  final String bin;
  final String shortName;
  final String fullName;

  const VietnamBankOption({
    required this.bin,
    required this.shortName,
    required this.fullName,
  });
}

/// EMVCo NAPAS 247 VietQR payload builder with CRC-16/CCITT-FALSE checksum.
class VietQrService {
  VietQrService._();

  static const List<VietnamBankOption> supportedBanks = [
    VietnamBankOption(bin: '970422', shortName: 'MB Bank', fullName: 'Ngân hàng Quân Đội'),
    VietnamBankOption(bin: '970436', shortName: 'Vietcombank', fullName: 'TMCP Ngoại Thương'),
    VietnamBankOption(bin: '970407', shortName: 'Techcombank', fullName: 'TMCP Kỹ Thương'),
    VietnamBankOption(bin: '970416', shortName: 'ACB', fullName: 'TMCP Á Châu'),
    VietnamBankOption(bin: '970418', shortName: 'BIDV', fullName: 'TMCP Đầu Tư & PT'),
    VietnamBankOption(bin: '970432', shortName: 'VPBank', fullName: 'TMCP Việt Nam Thịnh Vượng'),
    VietnamBankOption(bin: '970423', shortName: 'TPBank', fullName: 'TMCP Tiên Phong'),
    VietnamBankOption(bin: '970415', shortName: 'VietinBank', fullName: 'TMCP Công Thương'),
  ];

  static String bankNameForBin(String bin) {
    for (final bank in supportedBanks) {
      if (bank.bin == bin) return bank.shortName;
    }
    return 'Bank ($bin)';
  }

  /// Sanitizes Vietnamese room/member names into uppercase ASCII memo codes
  /// compatible with all NAPAS 247 banking apps.
  static String buildReconciliationMemo({
    required String groupName,
    required String memberName,
  }) {
    final cleanGroup = _stripDiacritics(groupName)
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '');
    final cleanMember = _stripDiacritics(memberName)
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '');
    final groupCode = cleanGroup.isEmpty ? 'ROOM' : cleanGroup;
    final memberCode = cleanMember.isEmpty ? 'MEM' : cleanMember;
    final raw = 'SB_${groupCode}_$memberCode';
    return raw.length > 25 ? raw.substring(0, 25) : raw;
  }

  /// Generates a valid EMVCo QR string compliant with NAPAS 247 (VietQR).
  static String buildNapas247Payload({
    required String bankBin,
    required String accountNumber,
    required int amountVnd,
    required String memo,
  }) {
    final sanitizedAccount = accountNumber.trim().replaceAll(RegExp(r'\s+'), '');
    final sanitizedBin = bankBin.trim().replaceAll(RegExp(r'\s+'), '');
    final sanitizedMemo =
        _stripDiacritics(memo).replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();

    // Tag 00: Payload Format Indicator, Tag 01: 12 = Dynamic QR, 11 = Static
    final String tag00 = _tlv('00', '01');
    final String tag01 = _tlv('01', amountVnd > 0 ? '12' : '11');

    // Tag 38: Merchant Account Information (NAPAS VietQR GUID A000000727)
    final String beneficiaryOrg =
        _tlv('00', sanitizedBin) + _tlv('01', sanitizedAccount);
    final String tag38Body =
        _tlv('00', 'A000000727') +
        _tlv('01', beneficiaryOrg) +
        _tlv('02', 'QRIBFTTA');
    final String tag38 = _tlv('38', tag38Body);

    // Tag 53: Currency (704 = VND), Tag 54: Transaction Amount, Tag 58: Country
    final String tag53 = _tlv('53', '704');
    final String tag54 =
        amountVnd > 0 ? _tlv('54', amountVnd.toString()) : '';
    final String tag58 = _tlv('58', 'VN');

    // Tag 62: Additional Data Field Template (Subtag 08 = Purpose / Memo)
    final String boundedMemo =
        sanitizedMemo.length > 25 ? sanitizedMemo.substring(0, 25) : sanitizedMemo;
    final String tag62 =
        boundedMemo.isNotEmpty ? _tlv('62', _tlv('08', boundedMemo)) : '';

    final String withoutCrc =
        '$tag00$tag01$tag38$tag53$tag54$tag58${tag62}6304';
    final String crc = crc16CcittFalse(withoutCrc);
    return '$withoutCrc$crc';
  }

  /// Standard EMVCo CRC-16/CCITT-FALSE: initial = 0xFFFF, poly = 0x1021.
  static String crc16CcittFalse(String input) {
    final bytes = utf8.encode(input);
    int crc = 0xFFFF;
    for (final byte in bytes) {
      crc ^= (byte << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  static String _tlv(String tag, String value) {
    final lengthStr = value.length.toString().padLeft(2, '0');
    return '$tag$lengthStr$value';
  }

  static String _stripDiacritics(String input) {
    const String withDiacritics =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
        'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const String withoutDiacritics =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      final idx = withDiacritics.indexOf(ch);
      buffer.write(idx >= 0 ? withoutDiacritics[idx] : ch);
    }
    return buffer.toString();
  }
}
