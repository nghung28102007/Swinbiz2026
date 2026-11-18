import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../providers/savage_bot_provider.dart';
import '../services/hybrid_nlp_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/edit_transaction_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToSplitQr;

  const HomeScreen({
    super.key,
    required this.onNavigateToSplitQr,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _feedScrollController = ScrollController();
  late final AnimationController _pulseController;
  late final Animation<double> _dotPulseAnimation;

  final SpeechToText _speechToText = SpeechToText();
  ParsedExpenseResult? _liveParsedPreview;
  bool _speechInitialized = false;
  bool _isVoiceListening = false;
  bool _isSimulatedVoiceRunning = false;
  bool _hasSubmittedCurrentVoiceSession = false;
  bool _isSharedRoomExpense = false;
  bool _sharedToggleManualOverride = false;
  String _activeVoiceLocale = kIsWeb ? 'vi-VN' : 'vi_VN';
  double _soundLevel = 0.0;
  int _placeholderIndex = 0;
  Timer? _placeholderTimer;

  static const List<String> _rotatingHints = [
    'Gõ tự nhiên: "bún bò huế 45k", "xăng 50 cành"...',
    'Thử gõ: "trà sữa phê la 55k" hoặc "cơm sườn 35k"...',
    'Thử gõ: "tiền phòng 1 củ 2" hoặc "grab đi học 28k"...',
    'Thử gõ: "mua skin liên quân 150k", "cafe muối 32k"...',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _dotPulseAnimation = Tween<double>(begin: 0.75, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _inputController.addListener(_onInputChanged);

    _placeholderTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && _inputController.text.isEmpty) {
        setState(() {
          _placeholderIndex = (_placeholderIndex + 1) % _rotatingHints.length;
        });
      }
    });
  }

  void _onInputChanged() {
    final raw = _inputController.text;
    final parsed = HybridNlpService.parseNaturalInput(raw);
    setState(() {
      _liveParsedPreview = parsed;
      if (raw.trim().isEmpty) {
        _isSharedRoomExpense = false;
        _sharedToggleManualOverride = false;
      } else if (!_sharedToggleManualOverride && parsed != null) {
        _isSharedRoomExpense =
            HybridNlpService.isLikelySharedExpense(raw, parsed.category);
      }
    });
  }

  @override
  void dispose() {
    _placeholderTimer?.cancel();
    if (_speechInitialized) {
      _speechToText.cancel();
    }
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _feedScrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _copyRoastCard(
    ExpenseTransaction tx,
    String reply,
    bool isSavage,
  ) {
    HapticFeedback.selectionClick();
    final modeTag = isSavage ? 'SAVAGE ROAST' : 'QUÂN SƯ AI';
    final shareText =
        '[$modeTag • SavageBot]\n'
        'Khoản chi: ${tx.title} (-${HybridNlpService.formatVnd(tx.amountVnd)})\n'
        'Người chi: ${tx.payerName}\n'
        'AI phán: "$reply"';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: isSavage ? AppColors.rose : AppColors.emerald,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        content: Text(
          isSavage
              ? 'Đã sao chép thẻ Roast AI để chia sẻ nhóm.'
              : 'Đã sao chép lời khuyên Quân Sư AI.',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _handleDeleteTransaction(
    String txId,
    SavageBotNotifier notifier,
  ) {
    HapticFeedback.mediumImpact();
    final deleted = notifier.deleteTransaction(txId);
    if (deleted != null && mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.darkElevatedSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          content: Text(
            'Đã xóa "${deleted.transaction.title}" (${HybridNlpService.formatVnd(deleted.transaction.amountVnd)})',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          action: SnackBarAction(
            label: 'Hoàn tác',
            textColor: AppColors.emerald,
            onPressed: () {
              notifier.restoreDeletedTransaction(
                deleted.transaction,
                linkedSplit: deleted.linkedSplit,
              );
            },
          ),
        ),
      );
    }
  }

  void _submitExpense(String rawText, {bool? forceShared}) {
    final notifier = ref.read(savageBotProvider.notifier);
    final parsed = HybridNlpService.parseNaturalInput(rawText);
    final bool shouldShare = forceShared ??
        (_sharedToggleManualOverride
            ? _isSharedRoomExpense
            : ((parsed != null &&
                    HybridNlpService.isLikelySharedExpense(
                      rawText,
                      parsed.category,
                    )) ||
                _isSharedRoomExpense));

    final success = notifier.addExpenseFromInput(
      rawText,
      isSharedRoomExpense: shouldShare,
    );
    HapticFeedback.mediumImpact();

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.rose,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          content: const Text(
            'Hãy nhập món kèm số tiền nhé! (VD: "phở bò 45k", "tiền điện 350 cành", "trọ 1 củ 2")',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      );
      return;
    }

    if (shouldShare) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.violet,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          content: const Text(
            'Đã tự động đẩy khoản chi chung sang tab Chia Tiền QR!',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      );
    }

    _inputController.clear();
    setState(() {
      _liveParsedPreview = null;
      _isSharedRoomExpense = false;
      _sharedToggleManualOverride = false;
    });

    Future.delayed(const Duration(milliseconds: 120), () {
      if (_feedScrollController.hasClients) {
        _feedScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<bool> _ensureSpeechInitialized() async {
    if (_speechInitialized) return true;
    try {
      final bool available = await _speechToText.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
        options: [SpeechToText.androidNoBluetooth],
      );
      if (!available) return false;

      _speechInitialized = true;
      final locales = await _speechToText.locales();
      for (final locale in locales) {
        if (locale.localeId.toLowerCase().startsWith('vi')) {
          _activeVoiceLocale = locale.localeId;
          break;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (_isSimulatedVoiceRunning) return;

    if (_isVoiceListening) {
      HapticFeedback.lightImpact();
      await _speechToText.stop();
      if (!mounted) return;
      setState(() {
        _isVoiceListening = false;
        _soundLevel = 0.0;
      });
      _finalizeVoiceInputIfReady();
      return;
    }

    HapticFeedback.mediumImpact();
    final bool ready = await _ensureSpeechInitialized();
    if (!mounted) return;

    if (!ready) {
      _showVoiceFallbackPrompt(
        'Thiết bị/trình duyệt chưa cấp quyền Mic hoặc chưa hỗ trợ Speech-to-Text.',
      );
      return;
    }

    _hasSubmittedCurrentVoiceSession = false;
    _inputController.clear();
    setState(() {
      _liveParsedPreview = null;
      _isVoiceListening = true;
      _soundLevel = 0.0;
    });

    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        onSoundLevelChange: (level) {
          if (mounted && _isVoiceListening) {
            setState(() => _soundLevel = level);
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: _activeVoiceLocale,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 20),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVoiceListening = false;
        _soundLevel = 0.0;
      });
      _showVoiceFallbackPrompt('Không thể bật micro lúc này.');
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    final words = result.recognizedWords;
    if (words.isNotEmpty) {
      _inputController.text = words;
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: _inputController.text.length),
      );
    }

    if (result.finalResult) {
      setState(() {
        _isVoiceListening = false;
        _soundLevel = 0.0;
      });
      _finalizeVoiceInputIfReady();
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if (status == SpeechToText.doneStatus) {
      setState(() {
        _isVoiceListening = false;
        _soundLevel = 0.0;
      });
      _finalizeVoiceInputIfReady();
    } else if (status == SpeechToText.notListeningStatus ||
        status == 'doneNoResult') {
      setState(() {
        _isVoiceListening = false;
        _soundLevel = 0.0;
      });
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() {
      _isVoiceListening = false;
      _soundLevel = 0.0;
    });

    if (_hasSubmittedCurrentVoiceSession) return;
    final msg = error.errorMsg.toLowerCase();
    if (msg.contains('no_match') || msg.contains('no-speech')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.darkBorderStrong,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          content: const Text(
            'Chưa nghe rõ giọng nói. Thử nói gần mic hơn (VD: "bún bò 45k").',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
      return;
    }

    _showVoiceFallbackPrompt(
      'Lỗi nhận diện giọng nói (${error.errorMsg}).',
    );
  }

  void _finalizeVoiceInputIfReady() {
    if (_hasSubmittedCurrentVoiceSession || !mounted) return;
    final spoken = _inputController.text.trim();
    if (spoken.isEmpty) return;

    final parsed = HybridNlpService.parseNaturalInput(spoken);
    if (parsed != null) {
      _hasSubmittedCurrentVoiceSession = true;
      _submitExpense(spoken);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.violet,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          content: Text(
            'Đã nghe: "$spoken" — hãy nói hoặc gõ thêm số tiền nhé (VD: 45k)!',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
  }

  void _showVoiceFallbackPrompt(String reason) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkElevatedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        duration: const Duration(seconds: 5),
        content: Text(
          '$reason Dùng kịch bản giọng nói mẫu để demo?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        action: SnackBarAction(
          label: 'Chạy mẫu',
          textColor: AppColors.emerald,
          onPressed: _runVoiceNoteSimulation,
        ),
      ),
    );
  }

  /// Stage-safe backup simulation (accessible via long-press or fallback action)
  Future<void> _runVoiceNoteSimulation() async {
    if (_isSimulatedVoiceRunning || _isVoiceListening) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSimulatedVoiceRunning = true);

    const simulatedSpeech = 'Ăn lẩu bò tự sôi cùng phòng 120k';
    _inputController.text = '';
    for (int i = 1; i <= simulatedSpeech.length; i++) {
      await Future.delayed(const Duration(milliseconds: 24));
      if (!mounted) return;
      _inputController.text = simulatedSpeech.substring(0, i);
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: _inputController.text.length),
      );
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _isSimulatedVoiceRunning = false);
    _submitExpense(simulatedSpeech, forceShared: true);
  }

  void _openOcrScannerModal(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _VisionOcrScannerSheet(
        onScanCompleted: (template) {
          ref
              .read(savageBotProvider.notifier)
              .addMultiItemReceiptScan(template: template);
        },
        onRealScanCompleted: (result) {
          ref
              .read(savageBotProvider.notifier)
              .addScannedReceiptResult(result);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final botState = ref.watch(savageBotProvider);
    final notifier = ref.read(savageBotProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSavage = botState.activePersona == PersonaMode.savage;
    final bool isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 100 ||
        MediaQuery.sizeOf(context).height < 640;

    final Color surfaceColor = AppColors.surface(isDark);
    final Color secondarySurface = AppColors.secondarySurface(isDark);
    final Color borderColor = AppColors.border(isDark);
    final Color textPrimary = AppColors.textPrimary(isDark);
    final Color textSecondary = AppColors.textSecondary(isDark);
    final Color personaAccent = isSavage ? AppColors.rose : AppColors.emerald;

    final double safeRatio = botState.dailyBaseAllowance <= 0
        ? 0.0
        : (botState.dailySafeToSpend / botState.dailyBaseAllowance)
            .clamp(0.0, 1.0);
    final Color batteryColor = safeRatio > 0.5
        ? AppColors.emerald
        : (safeRatio > 0.2 ? AppColors.amber : AppColors.rose);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: [
            // 1. TOP PERSONA SWITCHER + GAMIFIED STREAK PILL
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: secondarySurface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              notifier.setPersona(PersonaMode.savage);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                gradient: isSavage
                                    ? const LinearGradient(
                                        colors: [
                                          AppColors.rose,
                                          AppColors.roseDark,
                                        ],
                                      )
                                    : null,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: Center(
                                child: Text(
                                  'Mỏ Hỗn (Roast)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isSavage
                                        ? Colors.white
                                        : textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              notifier.setPersona(PersonaMode.coach);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                gradient: !isSavage
                                    ? const LinearGradient(
                                        colors: [
                                          AppColors.emerald,
                                          AppColors.emeraldDark,
                                        ],
                                      )
                                    : null,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: Center(
                                child: Text(
                                  'Quân Sư (Coach)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: !isSavage
                                        ? Colors.white
                                        : textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.amber.withValues(alpha: 0.2),
                        AppColors.rose.withValues(alpha: 0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    'Chuỗi ${botState.noBobaStreakDays}d',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.amber,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 2. HERO DASHBOARD (Auto-collapses cleanly when keyboard opens)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: isKeyboardOpen
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [
                            AppColors.darkElevatedSurface,
                            AppColors.darkSecondarySurface,
                          ]
                        : const [
                            Colors.white,
                            Color(0xFFF8FAFC),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                    color: personaAccent.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: personaAccent.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ScaleTransition(
                                    scale: _dotPulseAnimation,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: batteryColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      botState.dailySafeToSpend == 0 &&
                                              botState.totalSpentThisMonth > 0
                                          ? 'Đã chạm trần hạn mức ngày!'
                                          : 'Hôm nay tiêu thêm được',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: botState.dailySafeToSpend == 0 &&
                                                botState.totalSpentThisMonth > 0
                                            ? AppColors.rose
                                            : textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  HybridNlpService.formatVnd(
                                    botState.dailySafeToSpend,
                                  ),
                                  style: TextStyle(
                                    fontSize: 29,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.8,
                                    color: botState.dailySafeToSpend == 0 &&
                                            botState.totalSpentThisMonth > 0
                                        ? AppColors.rose
                                        : textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (botState.dailySafeToSpend == 0 &&
                                      botState.totalSpentThisMonth > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.rose
                                            .withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: const Text(
                                        'Hết Pin ví ngày',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.rose,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.emerald
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      'Sống khỏe: ${botState.predictedRunwayDays} ngày',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.emerald,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.violet
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      'Quỹ tháng: ${HybridNlpService.formatCompactVnd(botState.remainingMonthlyBudget)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.violetLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Unified Wallet Battery % Donut Gauge
                        SizedBox(
                          width: 92,
                          height: 92,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  startDegreeOffset: -90,
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 28,
                                  sections: _buildBatterySections(
                                    safeRatio: safeRatio,
                                    batteryColor: batteryColor,
                                    trackColor: isDark
                                        ? AppColors.darkBorderStrong
                                        : AppColors.lightBorder,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${(safeRatio * 100).round()}%',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      color: batteryColor,
                                    ),
                                  ),
                                  Text(
                                    'Pin ví',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: safeRatio,
                        minHeight: 7,
                        backgroundColor: isDark
                            ? AppColors.darkBorderStrong
                            : AppColors.lightBorder,
                        valueColor: AlwaysStoppedAnimation<Color>(batteryColor),
                      ),
                    ),
                  ],
                ),
              ),
              secondChild: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: batteryColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.battery_charging_full_rounded,
                      size: 16,
                      color: batteryColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pin ví hôm nay: ${HybridNlpService.formatVnd(botState.dailySafeToSpend)} (${(safeRatio * 100).round()}%)',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${botState.predictedRunwayDays}d',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emerald,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 3. INTERACTIVE SAVAGEBOT CONVERSATIONAL STREAM
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 11, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isSavage
                                  ? 'Trợ Lý Mỏ Hỗn AI'
                                  : 'Cố Vấn Quân Sư AI',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${botState.tier1RatioPercent.toStringAsFixed(0)}% 0đ',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.emerald,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${botState.transactions.length} GD',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: botState.transactions.isEmpty
                          ? Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(18),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkElevatedSurface
                                        : AppColors.lightSecondarySurface,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.lg),
                                    border: Border.all(
                                      color: (isSavage
                                              ? AppColors.rose
                                              : AppColors.emerald)
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        isSavage
                                            ? 'Trợ lý Mỏ Hỗn đã sẵn sàng!'
                                            : 'Quân sư Tài chính đã sẵn sàng!',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w900,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        botState.latestSpeechBubble,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          height: 1.45,
                                          color: textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Mẹo: Gõ tự nhiên ("bún bò 45k", "trà sữa năm mươi lăm nghìn") hoặc bấm Mic để nói.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.emerald,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                        controller: _feedScrollController,
                        padding: const EdgeInsets.all(14),
                        physics: const BouncingScrollPhysics(),
                        itemCount: botState.transactions.length,
                        itemBuilder: (context, index) {
                          final tx = botState.transactions[
                              botState.transactions.length - 1 - index];
                          final reply =
                              isSavage ? tx.savageRoast : tx.coachAdvice;
                          final timeLabel =
                              DateFormat('HH:mm').format(tx.timestamp);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Dismissible(
                              key: ValueKey('home_tx_${tx.id}'),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) =>
                                  _handleDeleteTransaction(tx.id, notifier),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 18),
                                decoration: BoxDecoration(
                                  color: AppColors.rose.withValues(alpha: 0.18),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.lg),
                                  border: Border.all(
                                    color:
                                        AppColors.rose.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Vuốt để xóa',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.rose,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppColors.rose,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // User Natural Input Bubble (Tap to Edit/Delete)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: GestureDetector(
                                      onTap: () => showEditTransactionDialog(
                                        context: context,
                                        transaction: tx,
                                        members: botState.members,
                                        onSave: ({
                                          required title,
                                          required amountVnd,
                                          required category,
                                          required payerName,
                                        }) {
                                          notifier.editTransaction(
                                            tx.id,
                                            title: title,
                                            amountVnd: amountVnd,
                                            category: category,
                                            payerName: payerName,
                                          );
                                        },
                                        onDelete: () =>
                                            _handleDeleteTransaction(
                                          tx.id,
                                          notifier,
                                        ),
                                      ),
                                    child: Container(
                                      constraints:
                                          const BoxConstraints(maxWidth: 310),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 13,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.darkElevatedSurface
                                            : AppColors.lightSecondarySurface,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(18),
                                          topRight: Radius.circular(18),
                                          bottomLeft: Radius.circular(18),
                                          bottomRight: Radius.circular(4),
                                        ),
                                        border: Border.all(
                                          color: tx.category.color
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            alignment: WrapAlignment.end,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: tx.category.color
                                                      .withValues(alpha: 0.16),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  tx.category.labelVi,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: tx.category.color,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '${tx.payerName} • $timeLabel',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  tx.title,
                                                  style: TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: textPrimary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                '${tx.isIncome ? '+' : '-'}${HybridNlpService.formatVnd(tx.amountVnd)}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w900,
                                                  color: tx.isIncome
                                                      ? AppColors.emerald
                                                      : personaAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                tx.routeTier ==
                                                        NlpRouteTier
                                                            .tier1LocalRegex
                                                    ? '${tx.latencyMs.toStringAsFixed(1)}ms • 0đ'
                                                    : 'OCR/LLM • 110đ',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: textSecondary,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Icon(
                                                Icons.edit_outlined,
                                                size: 12,
                                                color: textSecondary,
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onTap: () =>
                                                    _handleDeleteTransaction(
                                                  tx.id,
                                                  notifier,
                                                ),
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 2,
                                                    vertical: 1,
                                                  ),
                                                  child: Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 13.5,
                                                    color: AppColors.rose,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Bot Persona Reaction Bubble (Left-aligned, tap to copy Roast Card)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: GestureDetector(
                                    onTap: () =>
                                        _copyRoastCard(tx, reply, isSavage),
                                    child: Container(
                                      constraints:
                                          const BoxConstraints(maxWidth: 330),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: personaAccent.withValues(
                                          alpha: isDark ? 0.13 : 0.08,
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(4),
                                          topRight: Radius.circular(18),
                                          bottomLeft: Radius.circular(18),
                                          bottomRight: Radius.circular(18),
                                        ),
                                        border: Border.all(
                                          color: personaAccent.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            reply,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              height: 1.38,
                                              fontWeight: FontWeight.w600,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.share_outlined,
                                                  size: 10.5,
                                                  color: textSecondary,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  isSavage
                                                      ? 'Chạm để copy câu khịa'
                                                      : 'Chạm để copy lời khuyên',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 4. BOTTOM THUMB-ZONE SMART NLP DOCK
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: _liveParsedPreview != null
                      ? AppColors.emerald
                      : (isDark ? AppColors.darkBorderStrong : borderColor),
                  width: _liveParsedPreview != null ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // LIVE VOICE LISTENING BANNER
                  if (_isVoiceListening)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.rose.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.rose.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.graphic_eq_rounded,
                            size: (18 + _soundLevel.clamp(0.0, 6.0)).toDouble(),
                            color: AppColors.rose,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Đang nghe tiếng Việt... Nói VD: "trà sữa 55k" (chạm mic để dừng)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // LIVE NLP INTENT PREVIEW BAR
                  if (_liveParsedPreview != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.emerald.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _liveParsedPreview!.category.color,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bóc tách: ${_liveParsedPreview!.itemTitle} (${_liveParsedPreview!.category.labelVi})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                                Builder(
                                  builder: (_) {
                                    final detectedPayer =
                                        HybridNlpService.detectMemberInQuery(
                                              _inputController.text,
                                              botState.members,
                                            ) ??
                                            botState.activePayer;
                                    return Text(
                                      _isSharedRoomExpense
                                          ? '$detectedPayer • 0đ API • Đẩy Chia QR'
                                          : '$detectedPayer • Tier-1 (${_liveParsedPreview!.latencyMs}ms) • 0đ API',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.emerald,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            HybridNlpService.formatVnd(
                              _liveParsedPreview!.amountVnd,
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.emerald,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Overflow-safe Horizontal Action Strip: Members + Chia phòng + OCR + Split QR
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...botState.members.map((member) {
                          final isSelected = botState.activePayer == member;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                notifier.setActivePayer(member);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.violet
                                      : secondarySurface,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  member,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? Colors.white
                                        : textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        // Closed-Loop Chia phòng Toggle Chip
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _sharedToggleManualOverride = true;
                                _isSharedRoomExpense = !_isSharedRoomExpense;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _isSharedRoomExpense
                                    ? AppColors.amber.withValues(alpha: 0.22)
                                    : secondarySurface,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                                border: Border.all(
                                  color: _isSharedRoomExpense
                                      ? AppColors.amber
                                      : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                'Chia phòng',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _isSharedRoomExpense
                                      ? AppColors.amber
                                      : textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Interactive Vision OCR Receipt Scanner Button
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            onTap: () => _openOcrScannerModal(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.emerald.withValues(alpha: 0.15),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                              ),
                              child: const Text(
                                'Quét Bill AI',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.emerald,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Jump to VietQR Split
                        InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          onTap: widget.onNavigateToSplitQr,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Text(
                              'Chia QR',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.blue,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Natural Shorthand Input Field + Voice Note + Send
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          onSubmitted: _submitExpense,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: _isVoiceListening
                                ? 'Đang nghe micro (nói món + số tiền)...'
                                : (_isSimulatedVoiceRunning
                                    ? 'Đang chạy giọng nói mẫu...'
                                    : _rotatingHints[_placeholderIndex]),
                            hintStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: textSecondary,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: secondarySurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onLongPress: _runVoiceNoteSimulation,
                        child: IconButton.filledTonal(
                          onPressed: _toggleVoiceInput,
                          style: IconButton.styleFrom(
                            backgroundColor:
                                (_isVoiceListening || _isSimulatedVoiceRunning)
                                    ? AppColors.rose.withValues(alpha: 0.2)
                                    : AppColors.violet.withValues(alpha: 0.18),
                          ),
                          icon: Icon(
                            (_isVoiceListening || _isSimulatedVoiceRunning)
                                ? Icons.stop_circle_rounded
                                : Icons.mic_rounded,
                            size: 19,
                            color:
                                (_isVoiceListening || _isSimulatedVoiceRunning)
                                    ? AppColors.rose
                                    : AppColors.violet,
                          ),
                          tooltip:
                              'Nói để ghi chi tiêu (Giữ lâu: chạy câu mẫu)',
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filled(
                        onPressed: () => _submitExpense(_inputController.text),
                        style: IconButton.styleFrom(
                          backgroundColor: personaAccent,
                        ),
                        icon: const Icon(
                          Icons.send_rounded,
                          size: 18,
                          color: Colors.white,
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
    );
  }

  List<PieChartSectionData> _buildBatterySections({
    required double safeRatio,
    required Color batteryColor,
    required Color trackColor,
  }) {
    final double remainingPct = (safeRatio * 100).clamp(0.0, 100.0);
    final double usedPct = (100.0 - remainingPct).clamp(0.0, 100.0);

    if (remainingPct <= 0.5) {
      return [
        PieChartSectionData(
          value: 100,
          color: AppColors.rose.withValues(alpha: 0.35),
          radius: 12,
          showTitle: false,
        ),
      ];
    }

    return [
      PieChartSectionData(
        value: remainingPct,
        color: batteryColor,
        radius: 13,
        showTitle: false,
      ),
      if (usedPct > 0.5)
        PieChartSectionData(
          value: usedPct,
          color: trackColor,
          radius: 10,
          showTitle: false,
        ),
    ];
  }
}

/// Interactive Vision OCR Receipt Scanner Modal Sheet (Real Photo + 3 Templates)
class _VisionOcrScannerSheet extends StatefulWidget {
  final void Function(OcrReceiptTemplate template) onScanCompleted;
  final void Function(ScannedReceiptResult result) onRealScanCompleted;

  const _VisionOcrScannerSheet({
    required this.onScanCompleted,
    required this.onRealScanCompleted,
  });

  @override
  State<_VisionOcrScannerSheet> createState() => _VisionOcrScannerSheetState();
}

class _VisionOcrScannerSheetState extends State<_VisionOcrScannerSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _laserController;
  final ImagePicker _imagePicker = ImagePicker();
  OcrReceiptTemplate _selectedTemplate = OcrReceiptTemplate.circleK;
  Uint8List? _pickedImageBytes;
  String _pickedMimeType = 'image/jpeg';
  String? _scanError;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  Future<void> _pickReceiptImage(ImageSource source) async {
    if (_isScanning) return;
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 75,
      );
      if (picked == null || !mounted) return;
      final Uint8List bytes = await picked.readAsBytes();
      final String lowerName = picked.name.toLowerCase();
      final String mime = lowerName.endsWith('.png')
          ? 'image/png'
          : (lowerName.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
      if (!mounted) return;
      setState(() {
        _pickedImageBytes = bytes;
        _pickedMimeType = mime;
        _scanError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanError = 'Không thể mở ảnh: $e';
      });
    }
  }

  Future<void> _startScan() async {
    if (_isScanning) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isScanning = true;
      _scanError = null;
    });

    if (_pickedImageBytes != null) {
      final outcome = await HybridNlpService.scanReceiptImageWithAi(
        imageBytes: _pickedImageBytes!,
        mimeType: _pickedMimeType,
      );
      if (!mounted) return;
      if (outcome.result != null) {
        widget.onRealScanCompleted(outcome.result!);
        Navigator.of(context).pop();
      } else {
        setState(() {
          _isScanning = false;
          _scanError = outcome.error ?? 'Không thể đọc hóa đơn từ ảnh này.';
        });
      }
      return;
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    widget.onScanCompleted(_selectedTemplate);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkNavigationBg : Colors.white;
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Vision AI • Quét Hóa Đơn',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    _pickedImageBytes != null ? 'Gemini Vision' : '< 0.8s Demo',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.emerald,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Upload / Capture Real Receipt Photo Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isScanning
                        ? null
                        : () => _pickReceiptImage(ImageSource.gallery),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.emerald.withValues(alpha: 0.55),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(
                      Icons.photo_library_rounded,
                      size: 18,
                      color: AppColors.emerald,
                    ),
                    label: Text(
                      _pickedImageBytes == null
                          ? 'Chọn ảnh bill thật'
                          : 'Đổi ảnh khác',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emerald,
                      ),
                    ),
                  ),
                ),
                if (!kIsWeb) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isScanning
                          ? null
                          : () => _pickReceiptImage(ImageSource.camera),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.emerald.withValues(alpha: 0.55),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(
                        Icons.camera_alt_rounded,
                        size: 18,
                        color: AppColors.emerald,
                      ),
                      label: const Text(
                        'Chụp hóa đơn',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.emerald,
                        ),
                      ),
                    ),
                  ),
                ],
                if (_pickedImageBytes != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Dùng bill mẫu',
                    onPressed: _isScanning
                        ? null
                        : () => setState(() {
                              _pickedImageBytes = null;
                              _scanError = null;
                            }),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.rose,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            if (_pickedImageBytes == null) ...[
              // 3 Selectable Realistic Receipt Templates
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: OcrReceiptTemplate.values.map((tpl) {
                    final active = _selectedTemplate == tpl;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(tpl.label),
                        selected: active,
                        selectedColor: AppColors.emerald,
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : textSecondary,
                        ),
                        onSelected: _isScanning
                            ? null
                            : (_) => setState(() => _selectedTemplate = tpl),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Receipt Preview (Real Uploaded Image OR Template) with Laser Scan Line
            Stack(
              children: [
                if (_pickedImageBytes != null)
                  Container(
                    width: double.infinity,
                    height: 220,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkElevatedSurface
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: AppColors.emerald.withValues(alpha: 0.5),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg - 1),
                      child: Image.memory(
                        _pickedImageBytes!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                else
                  Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkElevatedSurface
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.emerald.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedTemplate.merchantHeader,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          Text(
                            _selectedTemplate.timeLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      ..._selectedTemplate.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ReceiptLine(
                            item: '1x ${item.title}',
                            price: HybridNlpService.formatVnd(item.amount),
                          ),
                        ),
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TỔNG CỘNG (${_selectedTemplate.items.length} MÓN)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppColors.emerald,
                            ),
                          ),
                          Text(
                            HybridNlpService.formatVnd(
                              _selectedTemplate.totalVnd,
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.emerald,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _laserController,
                  builder: (context, _) {
                    return Positioned(
                      top: 12 + (_laserController.value * 140),
                      left: 12,
                      right: 12,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.emerald,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.emerald.withValues(alpha: 0.8),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            if (_scanError != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.rose.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.rose.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _scanError!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.rose,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _isScanning ? null : _startScan,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  _pickedImageBytes != null
                      ? (_isScanning
                          ? 'Gemini Vision đang đọc hóa đơn...'
                          : 'Quét Hóa Đơn Thật (Gemini Vision)')
                      : (_isScanning
                          ? 'Đang bóc tách ${_selectedTemplate.items.length} dòng hóa đơn...'
                          : 'Bóc Tách Tự Động (${_selectedTemplate.items.length} Món)'),
                  style: const TextStyle(
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
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  final String item;
  final String price;

  const _ReceiptLine({required this.item, required this.price});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            item,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          price,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
