import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/design_tokens.dart';
import '../core/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cash Counting Page
// ─────────────────────────────────────────────────────────────────────────────

class CashCountingPage extends StatefulWidget {
  const CashCountingPage({super.key});

  @override
  State<CashCountingPage> createState() => _CashCountingPageState();
}

class _CashCountingPageState extends State<CashCountingPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // ── Denomination definitions ──────────────────────────────────────────────
  static const List<_Denomination> _denominations = [
    _Denomination(value: 1000, label: '฿1,000', type: _DenomType.bill, colorLight: Color(0xFF7B1FA2), colorDark: Color(0xFFCE93D8)),
    _Denomination(value: 500, label: '฿500', type: _DenomType.bill, colorLight: Color(0xFF1565C0), colorDark: Color(0xFF90CAF9)),
    _Denomination(value: 100, label: '฿100', type: _DenomType.bill, colorLight: Color(0xFFC62828), colorDark: Color(0xFFEF9A9A)),
    _Denomination(value: 50, label: '฿50', type: _DenomType.bill, colorLight: Color(0xFF0277BD), colorDark: Color(0xFF81D4FA)),
    _Denomination(value: 20, label: '฿20', type: _DenomType.bill, colorLight: Color(0xFF2E7D32), colorDark: Color(0xFFA5D6A7)),
    _Denomination(value: 10, label: '฿10', type: _DenomType.coin, colorLight: Color(0xFF795548), colorDark: Color(0xFFBCAAA4)),
    _Denomination(value: 5, label: '฿5', type: _DenomType.coin, colorLight: Color(0xFF546E7A), colorDark: Color(0xFFB0BEC5)),
    _Denomination(value: 2, label: '฿2', type: _DenomType.coin, colorLight: Color(0xFF616161), colorDark: Color(0xFFBDBDBD)),
    _Denomination(value: 1, label: '฿1', type: _DenomType.coin, colorLight: Color(0xFF757575), colorDark: Color(0xFFE0E0E0)),
  ];

  // ── State ─────────────────────────────────────────────────────────────────
  late final List<TextEditingController> _controllers;
  final TextEditingController _actualCashController = TextEditingController();
  final _numberFormat = NumberFormat('#,###');

  int _grandTotal = 0;
  int? _actualCash;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _denominations.length,
      (_) => TextEditingController(),
    );
    for (final c in _controllers) {
      c.addListener(_recalculate);
    }
    _actualCashController.addListener(_onActualCashChanged);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.removeListener(_recalculate);
      c.dispose();
    }
    _actualCashController.removeListener(_onActualCashChanged);
    _actualCashController.dispose();
    super.dispose();
  }

  void _recalculate() {
    int total = 0;
    for (int i = 0; i < _denominations.length; i++) {
      final count = int.tryParse(_controllers[i].text) ?? 0;
      total += _denominations[i].value * count;
    }
    if (total != _grandTotal) {
      setState(() => _grandTotal = total);
    }
  }

  void _onActualCashChanged() {
    final text = _actualCashController.text.replaceAll(',', '');
    final value = int.tryParse(text);
    if (value != _actualCash) {
      setState(() {
        _actualCash = value;
      });
    }
  }

  void _increment(int index) {
    final current = int.tryParse(_controllers[index].text) ?? 0;
    _controllers[index].text = '${current + 1}';
    // Move cursor to end
    _controllers[index].selection = TextSelection.fromPosition(
      TextPosition(offset: _controllers[index].text.length),
    );
  }

  void _decrement(int index) {
    final current = int.tryParse(_controllers[index].text) ?? 0;
    if (current > 0) {
      _controllers[index].text = '${current - 1}';
      _controllers[index].selection = TextSelection.fromPosition(
        TextPosition(offset: _controllers[index].text.length),
      );
    }
  }

  void _resetAll() {
    for (final c in _controllers) {
      c.clear();
    }
    _actualCashController.clear();
    setState(() {
      _grandTotal = 0;
      _actualCash = null;
    });
  }

  int _getRowTotal(int index) {
    final count = int.tryParse(_controllers[index].text) ?? 0;
    return _denominations[index].value * count;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = context.isDarkMode;
    final isSmall = context.screenWidth < 380;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: DesignTokens.containerMaxWidth),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: isSmall ? 12 : 20)),

              // ── Grand Total Card ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 20),
                  child: _GrandTotalCard(
                    total: _grandTotal,
                    numberFormat: _numberFormat,
                  ),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: isSmall ? 16 : 24)),

              // ── Section Header: ธนบัตร ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 20),
                  child: Text(
                    'ธนบัตร',
                    style: kanitTextStyle(
                      fontSize: isSmall ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: context.colors.primary,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 8)),

              // ── Bill rows ─────────────────────────────────────────────
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Bills: indices 0-4
                      return _DenominationRow(
                        denomination: _denominations[index],
                        controller: _controllers[index],
                        rowTotal: _getRowTotal(index),
                        numberFormat: _numberFormat,
                        onIncrement: () => _increment(index),
                        onDecrement: () => _decrement(index),
                        isDark: isDark,
                        isSmall: isSmall,
                        isFirst: index == 0,
                        isLast: index == 4,
                      );
                    },
                    childCount: 5,
                  ),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: isSmall ? 16 : 24)),

              // ── Section Header: เหรียญ ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 20),
                  child: Text(
                    'เหรียญ',
                    style: kanitTextStyle(
                      fontSize: isSmall ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: context.colors.primary,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 8)),

              // ── Coin rows ─────────────────────────────────────────────
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final actualIndex = index + 5; // Coins start at index 5
                      return _DenominationRow(
                        denomination: _denominations[actualIndex],
                        controller: _controllers[actualIndex],
                        rowTotal: _getRowTotal(actualIndex),
                        numberFormat: _numberFormat,
                        onIncrement: () => _increment(actualIndex),
                        onDecrement: () => _decrement(actualIndex),
                        isDark: isDark,
                        isSmall: isSmall,
                        isFirst: index == 0,
                        isLast: index == 3,
                      );
                    },
                    childCount: 4,
                  ),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: isSmall ? 16 : 24)),

              // ── Actual Cash Comparison Card ───────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 20),
                  child: _ActualCashCard(
                    controller: _actualCashController,
                    grandTotal: _grandTotal,
                    actualCash: _actualCash,
                    numberFormat: _numberFormat,
                    isDark: isDark,
                    isSmall: isSmall,
                  ),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: isSmall ? 16 : 24)),

              // ── Reset Button ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _grandTotal > 0 || _actualCash != null
                          ? () => _showResetConfirm(context)
                          : null,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        'ล้างค่าทั้งหมด',
                        style: kanitTextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: DesignTokens.borderRadiusMd,
                        ),
                        side: BorderSide(
                          color: _grandTotal > 0 || _actualCash != null
                              ? DesignTokens.errorMain
                              : context.colors.disabled,
                        ),
                        foregroundColor: DesignTokens.errorMain,
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: isSmall ? 24 : 32)),
            ],
          ),
        ),
      ),
    );
  }

  void _showResetConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.borderRadiusLg,
        ),
        title: Text(
          'ล้างค่าทั้งหมด?',
          style: kanitTextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'ข้อมูลที่กรอกไว้จะถูกลบทั้งหมด',
          style: kanitTextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'ยกเลิก',
              style: kanitTextStyle(fontSize: 14),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetAll();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.errorMain,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: DesignTokens.borderRadiusSm,
              ),
            ),
            child: Text(
              'ล้างค่า',
              style: kanitTextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

enum _DenomType { bill, coin }

class _Denomination {
  final int value;
  final String label;
  final _DenomType type;
  final Color colorLight;
  final Color colorDark;

  const _Denomination({
    required this.value,
    required this.label,
    required this.type,
    required this.colorLight,
    required this.colorDark,
  });

  IconData get icon => type == _DenomType.bill
      ? Icons.payments_outlined
      : Icons.monetization_on_outlined;

  Color color(bool isDark) => isDark ? colorDark : colorLight;
}

// ─────────────────────────────────────────────────────────────────────────────
// Grand Total Card
// ─────────────────────────────────────────────────────────────────────────────

class _GrandTotalCard extends StatelessWidget {
  const _GrandTotalCard({
    required this.total,
    required this.numberFormat,
  });

  final int total;
  final NumberFormat numberFormat;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A8A82), const Color(0xFF239089)]
              : [const Color(0xFF33BCB4), const Color(0xFF5CCDC6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DesignTokens.borderRadiusLg,
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.tealAccent : const Color(0xFF33BCB4))
                .withOpacity(isDark ? 0.2 : 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                'ยอดนับได้ทั้งหมด',
                style: kanitTextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: DesignTokens.durationFast,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Text(
              '฿${numberFormat.format(total)}',
              key: ValueKey<int>(total),
              style: kanitTextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Denomination Row
// ─────────────────────────────────────────────────────────────────────────────

class _DenominationRow extends StatelessWidget {
  const _DenominationRow({
    required this.denomination,
    required this.controller,
    required this.rowTotal,
    required this.numberFormat,
    required this.onIncrement,
    required this.onDecrement,
    required this.isDark,
    required this.isSmall,
    required this.isFirst,
    required this.isLast,
  });

  final _Denomination denomination;
  final TextEditingController controller;
  final int rowTotal;
  final NumberFormat numberFormat;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool isDark;
  final bool isSmall;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final denomColor = denomination.color(isDark);
    final hasValue = rowTotal > 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(12) : Radius.zero,
          bottom: isLast ? const Radius.circular(12) : Radius.zero,
        ),
        border: Border(
          left: BorderSide(color: context.colors.borderColor),
          right: BorderSide(color: context.colors.borderColor),
          top: isFirst
              ? BorderSide(color: context.colors.borderColor)
              : BorderSide.none,
          bottom: BorderSide(color: context.colors.borderColor),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 10 : 14,
        vertical: isSmall ? 8 : 10,
      ),
      child: Row(
        children: [
          // ── Denomination icon & label ──────────────────────────────
          Container(
            width: isSmall ? 32 : 36,
            height: isSmall ? 32 : 36,
            decoration: BoxDecoration(
              color: denomColor.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: DesignTokens.borderRadiusSm,
            ),
            child: Icon(
              denomination.icon,
              color: denomColor,
              size: isSmall ? 18 : 20,
            ),
          ),
          SizedBox(width: isSmall ? 8 : 12),
          SizedBox(
            width: isSmall ? 52 : 60,
            child: Text(
              denomination.label,
              style: kanitTextStyle(
                fontSize: isSmall ? 14 : 15,
                fontWeight: FontWeight.w600,
                color: denomColor,
              ),
            ),
          ),

          // ── Count input with +/- buttons ──────────────────────────
          SizedBox(width: isSmall ? 4 : 8),
          _StepperButton(
            icon: Icons.remove,
            onPressed: onDecrement,
            isDark: isDark,
            isSmall: isSmall,
          ),
          SizedBox(width: isSmall ? 2 : 4),
          SizedBox(
            width: isSmall ? 48 : 56,
            height: isSmall ? 34 : 38,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              style: kanitTextStyle(
                fontSize: isSmall ? 15 : 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black26,
                  fontSize: isSmall ? 15 : 16,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                isDense: true,
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: denomColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: isSmall ? 2 : 4),
          _StepperButton(
            icon: Icons.add,
            onPressed: onIncrement,
            isDark: isDark,
            isSmall: isSmall,
          ),

          // ── Row total ─────────────────────────────────────────────
          const Spacer(),
          AnimatedSwitcher(
            duration: DesignTokens.durationFast,
            child: Text(
              hasValue ? '฿${numberFormat.format(rowTotal)}' : '-',
              key: ValueKey<int>(rowTotal),
              style: kanitTextStyle(
                fontSize: isSmall ? 14 : 16,
                fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
                color: hasValue
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white24 : Colors.black26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stepper Button (+/-)
// ─────────────────────────────────────────────────────────────────────────────

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onPressed,
    required this.isDark,
    required this.isSmall,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isDark;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isSmall ? 30 : 34,
      height: isSmall ? 30 : 34,
      child: Material(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Icon(
            icon,
            size: isSmall ? 16 : 18,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Actual Cash Comparison Card
// ─────────────────────────────────────────────────────────────────────────────

class _ActualCashCard extends StatelessWidget {
  const _ActualCashCard({
    required this.controller,
    required this.grandTotal,
    required this.actualCash,
    required this.numberFormat,
    required this.isDark,
    required this.isSmall,
  });

  final TextEditingController controller;
  final int grandTotal;
  final int? actualCash;
  final NumberFormat numberFormat;
  final bool isDark;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    final diff = actualCash != null ? grandTotal - actualCash! : null;
    final diffLabel = diff == null
        ? null
        : diff > 0
            ? 'เกิน +${numberFormat.format(diff)} บาท'
            : diff < 0
                ? 'ขาด ${numberFormat.format(diff)} บาท'
                : 'พอดี ✓';
    final diffColor = diff == null
        ? null
        : diff > 0
            ? DesignTokens.successMain
            : diff < 0
                ? DesignTokens.errorMain
                : DesignTokens.successMain;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: DesignTokens.borderRadiusLg,
        border: Border.all(color: context.colors.borderColor),
        boxShadow: isDark ? null : DesignTokens.shadowXs,
      ),
      padding: EdgeInsets.all(isSmall ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.compare_arrows,
                color: context.colors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'เปรียบเทียบยอดเงินสด',
                style: kanitTextStyle(
                  fontSize: isSmall ? 15 : 16,
                  fontWeight: FontWeight.bold,
                  color: context.colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Actual cash input ──────────────────────────────────────
          Text(
            'ยอดเงินสดที่รับมาจริง',
            style: kanitTextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: kanitTextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              prefixText: '฿ ',
              prefixStyle: kanitTextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.colors.primary,
              ),
              hintText: 'ใส่ยอดเงินสดจริง',
              hintStyle: kanitTextStyle(
                fontSize: 16,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: context.colors.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),

          // ── Diff result ───────────────────────────────────────────
          if (diff != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: diffColor!.withOpacity(isDark ? 0.15 : 0.08),
                borderRadius: DesignTokens.borderRadiusMd,
                border: Border.all(
                  color: diffColor.withOpacity(0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    diff == 0
                        ? Icons.check_circle
                        : diff > 0
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                    color: diffColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: DesignTokens.durationFast,
                      child: Text(
                        diffLabel!,
                        key: ValueKey<String>(diffLabel),
                        style: kanitTextStyle(
                          fontSize: isSmall ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: diffColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
