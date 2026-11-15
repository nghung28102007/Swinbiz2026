import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/savage_bot_provider.dart';
import '../services/hybrid_nlp_service.dart';
import '../services/vietqr_service.dart';
import '../theme/app_tokens.dart';

/// Brand-new user onboarding screen to initialize a 100% blank wallet
/// with real personal/group details instead of pre-seeded demo data.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _isGroupMode = false;
  PersonaMode _selectedPersona = PersonaMode.savage;
  String _selectedBankBin = '970422';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _membersController = TextEditingController();
  final TextEditingController _budgetController =
      TextEditingController(text: '4500000');
  final TextEditingController _bankAccountController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _groupNameController.dispose();
    _membersController.dispose();
    _budgetController.dispose();
    _bankAccountController.dispose();
    super.dispose();
  }

  void _submitBlankWallet() {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(savageBotProvider.notifier);

    final int parsedBudget = int.tryParse(
          _budgetController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        4500000;

    if (!_isGroupMode) {
      final String userName =
          _nameController.text.trim().isEmpty ? 'Bạn' : _nameController.text.trim();
      notifier.completeNewUserOnboarding(
        groupName: 'Ví $userName',
        members: [userName],
        monthlyBudget: parsedBudget,
        activePersona: _selectedPersona,
        bankBin: _selectedBankBin,
        bankAccount: _bankAccountController.text.trim(),
      );
      return;
    }

    final List<String> parsedMembers = _membersController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final List<String> members = parsedMembers.isEmpty
        ? [
            _nameController.text.trim().isEmpty
                ? 'Bạn'
                : _nameController.text.trim(),
            'Bạn cùng phòng',
          ]
        : parsedMembers;
    final String groupName = _groupNameController.text.trim().isEmpty
        ? 'Nhóm chi tiêu'
        : _groupNameController.text.trim();

    notifier.completeNewUserOnboarding(
      groupName: groupName,
      members: members,
      monthlyBudget: parsedBudget,
      activePersona: _selectedPersona,
      bankBin: _selectedBankBin,
      bankAccount: _bankAccountController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final botState = ref.watch(savageBotProvider);
    final notifier = ref.read(savageBotProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color surface = AppColors.surface(isDark);
    final Color secondarySurface = AppColors.secondarySurface(isDark);
    final Color borderColor = AppColors.border(isDark);
    final Color textPrimary = AppColors.textPrimary(isDark);
    final Color textSecondary = AppColors.textSecondary(isDark);

    final int previewBudget = int.tryParse(
          _budgetController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        4500000;
    final int dailyAllowance =
        (previewBudget.clamp(500000, 100000000) / 30).round();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar with Logo + Theme Switch
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.emerald, AppColors.violet],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emerald.withValues(alpha: 0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SAVAGEBOT',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Thiết lập ví mới trong 10 giây',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      notifier.toggleThemeMode();
                    },
                    tooltip: 'Đổi Sáng/Tối',
                    icon: Icon(
                      botState.isDarkMode
                          ? Icons.wb_sunny_rounded
                          : Icons.dark_mode_rounded,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Main Setup Card
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bạn muốn dùng theo kiểu nào?',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ModeChoiceTile(
                            icon: Icons.person_rounded,
                            title: 'Cá nhân',
                            subtitle: 'Quản lý ví riêng',
                            selected: !_isGroupMode,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _isGroupMode = false);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ModeChoiceTile(
                            icon: Icons.groups_rounded,
                            title: 'Ở ghép / Nhóm',
                            subtitle: 'Chia bill VietQR',
                            selected: _isGroupMode,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _isGroupMode = true);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (!_isGroupMode) ...[
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Tên hoặc biệt danh của bạn',
                          hintText: 'VD: Hùng, Minh Anh...',
                          filled: true,
                          fillColor: secondarySurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: _groupNameController,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Tên nhóm / Phòng trọ',
                          hintText: 'VD: Phòng 402, Team Swinbiz...',
                          filled: true,
                          fillColor: secondarySurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _membersController,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Thành viên (cách nhau dấu phẩy)',
                          hintText: 'VD: Hùng, Nam, Linh',
                          helperText: 'Người đầu tiên là Thủ quỹ nhận QR',
                          filled: true,
                          fillColor: secondarySurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),
                    TextField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Ngân sách tháng này (VND)',
                        helperText:
                            'Hạn mức an toàn: ~${HybridNlpService.formatVnd(dailyAllowance)}/ngày',
                        filled: true,
                        fillColor: secondarySurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final preset in const [
                          (label: '3 triệu', val: '3000000'),
                          (label: '4.5 triệu', val: '4500000'),
                          (label: '6 triệu', val: '6000000'),
                        ])
                          ActionChip(
                            label: Text(
                              preset.label,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _budgetController.text = preset.val;
                              });
                            },
                          ),
                      ],
                    ),

                    if (_isGroupMode) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedBankBin,
                        isExpanded: true,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Ngân hàng nhận chia tiền VietQR',
                          filled: true,
                          fillColor: secondarySurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        items: VietQrService.supportedBanks
                            .map(
                              (bank) => DropdownMenuItem<String>(
                                value: bank.bin,
                                child: Text(
                                  '${bank.shortName} • ${bank.fullName}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedBankBin = val);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _bankAccountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Số tài khoản (tuỳ chọn)',
                          hintText: 'Nhập STK thật để quét QR hoặc để trống',
                          filled: true,
                          fillColor: secondarySurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    Text(
                      'Chọn giọng điệu AI đồng hành',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            selected: _selectedPersona == PersonaMode.savage,
                            label: const Center(
                              child: Text('🔥 Mỏ Hỗn'),
                            ),
                            selectedColor:
                                AppColors.rose.withValues(alpha: 0.2),
                            onSelected: (_) => setState(
                              () => _selectedPersona = PersonaMode.savage,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            selected: _selectedPersona == PersonaMode.coach,
                            label: const Center(
                              child: Text('🌱 Quân Sư'),
                            ),
                            selectedColor:
                                AppColors.emerald.withValues(alpha: 0.2),
                            onSelected: (_) => setState(
                              () => _selectedPersona = PersonaMode.coach,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Primary CTA: Start Blank Real User Wallet
              FilledButton.icon(
                onPressed: _submitBlankWallet,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: AppColors.darkScaffold,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
                icon: const Icon(Icons.rocket_launch_rounded, size: 19),
                label: const Text(
                  'Bắt đầu Ví Trắng (0đ đã chi)',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 6),

              // Secondary CTA: Load Hackathon Pitch Preset anytime
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  notifier.resetDemo();
                },
                icon: Icon(
                  Icons.play_circle_outline_rounded,
                  size: 17,
                  color: textSecondary,
                ),
                label: Text(
                  'Hoặc nạp kịch bản Demo Phòng 302 (Thuyết trình)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.emerald.withValues(alpha: 0.14)
              : AppColors.secondarySurface(isDark),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.emerald : AppColors.border(isDark),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? AppColors.emerald : AppColors.textSecondary(isDark),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
