import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/savage_bot_provider.dart';
import 'screens/analytics_screen.dart';
import 'screens/home_screen.dart';
import 'screens/judge_pitch_sheet.dart';
import 'screens/onboarding_screen.dart';
import 'screens/split_vietqr_screen.dart';
import 'services/vietqr_service.dart';
import 'theme/app_tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: SavageBotApp(),
    ),
  );
}

class SavageBotApp extends ConsumerWidget {
  const SavageBotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final botState = ref.watch(savageBotProvider);

    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightScaffold,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.emerald,
        brightness: Brightness.light,
        primary: AppColors.emerald,
        secondary: AppColors.violet,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.light().textTheme,
      ),
    );

    final ThemeData darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkScaffold,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.emerald,
        brightness: Brightness.dark,
        primary: AppColors.emerald,
        secondary: AppColors.violet,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme,
      ),
    );

    return MaterialApp(
      title: 'SavageBot • Swin-Biz Rockstar 2026',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: botState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: ResponsiveMobileFrame(
        child: botState.hasCompletedOnboarding
            ? const MainNavigationShell()
            : const OnboardingScreen(),
      ),
    );
  }
}

/// Centers the native mobile experience inside a phone frame on wide browsers
/// without ever clipping on 720p stage projectors, while staying 100% full-screen on mobile.
class ResponsiveMobileFrame extends StatelessWidget {
  final Widget child;

  const ResponsiveMobileFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 520) {
          return child;
        }
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final double frameHeight = math
            .min(900.0, math.max(520.0, constraints.maxHeight - 24))
            .clamp(0.0, constraints.maxHeight);

        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.3),
              radius: 1.1,
              colors: isDark
                  ? const [
                      Color(0xFF1E1B4B),
                      Color(0xFF020617),
                    ]
                  : const [
                      Color(0xFFE0E7FF),
                      Color(0xFFCBD5E1),
                    ],
            ),
          ),
          child: Center(
            child: Container(
              width: 440,
              height: frameHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(38),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorderStrong
                      : const Color(0xFF94A3B8),
                  width: 6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 40,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _selectedIndex = 0;

  void _openJudgePitchModal(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const JudgePitchSheet(),
    );
  }

  void _openGroupSettingsModal(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GroupSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final botState = ref.watch(savageBotProvider);
    final notifier = ref.read(savageBotProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> screens = [
      HomeScreen(
        onNavigateToSplitQr: () => setState(() => _selectedIndex = 1),
      ),
      const SplitVietQrScreen(),
      const AnalyticsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        titleSpacing: 14,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.emerald, AppColors.violet],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emerald.withValues(alpha: 0.35),
                    blurRadius: 10,
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
              child: GestureDetector(
                onTap: () => _openGroupSettingsModal(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'SAVAGEBOT',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                            color: AppColors.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.violet.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PRO AI',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: AppColors.violetLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${botState.groupName} • ${botState.members.join(', ')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary(isDark),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.tune_rounded,
                          size: 12,
                          color: AppColors.emerald,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _openJudgePitchModal(context),
            tooltip: 'Swin-Biz Rockstar 2026 Judge Console',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 18,
                color: AppColors.emerald,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              notifier.toggleThemeMode();
            },
            tooltip: 'Đổi giao diện Sáng/Tối',
            icon: Icon(
              botState.isDarkMode
                  ? Icons.wb_sunny_rounded
                  : Icons.dark_mode_rounded,
              size: 20,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Khởi tạo lại ví / Demo',
            icon: const Icon(Icons.restart_alt_rounded, size: 20),
            onSelected: (choice) {
              HapticFeedback.lightImpact();
              if (choice == 'fresh') {
                notifier.startFreshUserReset();
              } else if (choice == 'demo') {
                notifier.resetDemo();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'fresh',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_rounded,
                        size: 17, color: AppColors.emerald),
                    SizedBox(width: 8),
                    Text('Tạo lại Ví Trắng (User mới)'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'demo',
                child: Row(
                  children: [
                    Icon(Icons.play_circle_outline_rounded,
                        size: 17, color: AppColors.violetLight),
                    SizedBox(width: 8),
                    Text('Nạp kịch bản Demo (Phòng 302)'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) {
          HapticFeedback.selectionClick();
          setState(() => _selectedIndex = idx);
        },
        height: 66,
        backgroundColor: isDark ? AppColors.darkNavigationBg : Colors.white,
        indicatorColor: AppColors.emerald.withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_rounded),
            label: 'AI Trợ Lý',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_2_rounded),
            label: 'Chia Tiền QR',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_rounded),
            label: 'Phân Tích Ví',
          ),
        ],
      ),
    );
  }
}

/// Interactive Bottom Sheet to customize Group Name, Members, Budget & Bank Info live.
class _GroupSettingsSheet extends ConsumerStatefulWidget {
  const _GroupSettingsSheet();

  @override
  ConsumerState<_GroupSettingsSheet> createState() =>
      _GroupSettingsSheetState();
}

class _GroupSettingsSheetState extends ConsumerState<_GroupSettingsSheet> {
  late TextEditingController _groupController;
  late TextEditingController _accountController;
  late TextEditingController _budgetController;
  final TextEditingController _newMemberController = TextEditingController();

  late List<String> _members;
  late String _treasurerName;
  late String _bankBin;

  @override
  void initState() {
    super.initState();
    final botState = ref.read(savageBotProvider);
    _groupController = TextEditingController(text: botState.groupName);
    _accountController = TextEditingController(text: botState.bankAccount);
    _budgetController =
        TextEditingController(text: botState.monthlyBudget.toString());
    _members = List<String>.from(botState.members);
    _treasurerName = botState.treasurerName;
    _bankBin = botState.bankBin;
  }

  @override
  void dispose() {
    _groupController.dispose();
    _accountController.dispose();
    _budgetController.dispose();
    _newMemberController.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _newMemberController.text.trim();
    if (name.isEmpty || _members.contains(name)) return;
    setState(() {
      _members.add(name);
      _newMemberController.clear();
    });
  }

  void _save() {
    final parsedBudget =
        int.tryParse(_budgetController.text.trim()) ?? 4500000;
    ref.read(savageBotProvider.notifier).updateGroupSettings(
          groupName: _groupController.text,
          members: _members,
          treasurerName: _treasurerName,
          bankBin: _bankBin,
          bankAccount: _accountController.text,
          monthlyBudget: parsedBudget,
        );
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkNavigationBg : Colors.white;
    final secondarySurface = AppColors.secondarySurface(isDark);
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cấu Hình Nhóm & VietQR',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _groupController,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Tên nhóm / phòng trọ',
                  filled: true,
                  fillColor: secondarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Thành viên (${_members.length})',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _members.map((member) {
                  final isTreasurer = member == _treasurerName;
                  return InputChip(
                    label: Text(isTreasurer ? '👑 $member' : member),
                    selected: isTreasurer,
                    selectedColor: AppColors.violet.withValues(alpha: 0.22),
                    onSelected: (_) {
                      setState(() => _treasurerName = member);
                    },
                    onDeleted: _members.length > 1
                        ? () {
                            setState(() {
                              _members.remove(member);
                              if (!_members.contains(_treasurerName)) {
                                _treasurerName = _members.first;
                              }
                            });
                          }
                        : null,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newMemberController,
                      onSubmitted: (_) => _addMember(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Thêm thành viên mới (VD: Minh)...',
                        isDense: true,
                        filled: true,
                        fillColor: secondarySurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _addMember,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.violet,
                    ),
                    child: const Text(
                      'Thêm',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Ngân sách tháng (VNĐ)',
                  filled: true,
                  fillColor: secondarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [3000000, 4500000, 6000000, 8000000].map((val) {
                  return ActionChip(
                    label: Text('${(val / 1000000).toStringAsFixed(1)}M'),
                    onPressed: () {
                      setState(() => _budgetController.text = val.toString());
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: VietQrService.supportedBanks
                        .any((b) => b.bin == _bankBin)
                    ? _bankBin
                    : VietQrService.supportedBanks.first.bin,
                dropdownColor: bgColor,
                decoration: InputDecoration(
                  labelText: 'Ngân hàng nhận VietQR ($_treasurerName)',
                  filled: true,
                  fillColor: secondarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: VietQrService.supportedBanks.map((bank) {
                  return DropdownMenuItem(
                    value: bank.bin,
                    child: Text(
                      '${bank.shortName} (${bank.bin})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _bankBin = val);
                },
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _accountController,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Số tài khoản nhận tiền',
                  filled: true,
                  fillColor: secondarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: const Text(
                    'Lưu Cấu Hình Nhóm',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
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
