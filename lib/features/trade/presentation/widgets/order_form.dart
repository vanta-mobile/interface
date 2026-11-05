import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../application/providers.dart';
import '../../../market/application/market_providers.dart';
import '../../../market/domain/market_precision.dart';
import '../../domain/demo_order.dart';
import 'account_sheet.dart';
import 'order_review.dart';
import 'order_controls.dart';
import 'primitives.dart';

class OrderForm extends ConsumerStatefulWidget {
  const OrderForm({super.key});
  @override
  ConsumerState<OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends ConsumerState<OrderForm> {
  final price = TextEditingController();
  final quantity = TextEditingController();
  bool buy = true, marketOrder = false, reduceOnly = false;
  int leverage = 10;
  double fraction = 0;
  String? error;
  @override
  void dispose() {
    price.dispose();
    quantity.dispose();
    super.dispose();
  }

  OrderDraft get draft => OrderDraft(
    symbol: ref.read(symbolProvider),
    buy: buy,
    market: marketOrder,
    quantity: quantity.text,
    price: marketOrder ? ref.read(currentMarketProvider)?.price.toString() ?? '' : price.text,
    leverage: leverage,
    reduceOnly: reduceOnly,
    precision: ref.read(selectedPrecisionProvider),
  );

  Future<void> submit() async {
    if (!ref.read(accountProvider).connected) {
      showAccountSheet(context);
      return;
    }
    final invalid = ref.read(accountProvider.notifier).validate(draft);
    if (invalid != null) {
      setState(() => error = invalid);
      return;
    }
    final confirmed = await reviewOrder(context, draft);
    if (confirmed == true && mounted) {
      quantity.clear();
      setState(() {
        error = null;
        fraction = 0;
      });
      message(context, tr(context, 'submitted'));
    }
  }

  void allocate(double value) {
    final d = draft;
    if (d.parsedPrice <= Decimal.zero) return;
    final available = ref.read(accountProvider).available;
    quantity.text = marketInput(
      marketAllocation(
        available: available,
        fraction: Decimal.parse(value.toString()),
        price: d.parsedPrice,
        leverage: leverage,
        feeRate: demoFeeRate,
        precision: d.precision,
      ),
    );
    setState(() {
      fraction = value;
      error = null;
    });
  }

  Future<void> chooseLeverage() async {
    final selected = await showAppSheet<int>(context, LeverageSheet(value: leverage));
    if (selected != null) setState(() => leverage = selected);
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    final quote = ref.watch(currentMarketProvider);
    final base = ref.watch(symbolProvider).replaceAll('USDT', '');
    ref.listen<String>(orderPriceProvider, (_, value) {
      if (value.isNotEmpty) {
        setState(() {
          price.text = value;
          marketOrder = false;
        });
      }
    });
    ref.listen<String>(symbolProvider, (_, value) {
      price.clear();
      quantity.clear();
      setState(() {
        error = null;
        fraction = 0;
      });
    });
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OrderOptionButton(
                  label: tr(context, 'cross'),
                  icon: Icons.shield_outlined,
                  onTap: () => message(context, tr(context, 'leverageHint')),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OrderOptionButton(label: '$leverage×', onTap: chooseLeverage),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final isMarket in [false, true])
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() {
                      marketOrder = isMarket;
                      error = null;
                    }),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: marketOrder == isMarket ? AppColors.accent : AppColors.line,
                            width: marketOrder == isMarket ? 2 : 1,
                          ),
                        ),
                      ),
                      child: Text(
                        tr(context, isMarket ? 'market' : 'limit'),
                        style: TextStyle(
                          fontSize: 12,
                          color: marketOrder == isMarket ? AppColors.text : AppColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                for (final isBuy in [true, false])
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() {
                        buy = isBuy;
                        error = null;
                      }),
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: buy == isBuy
                              ? isBuy
                                    ? AppColors.positiveDepth
                                    : AppColors.negativeDepth
                              : null,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          tr(context, isBuy ? 'long' : 'short'),
                          style: TextStyle(
                            fontSize: 12,
                            color: buy == isBuy
                                ? isBuy
                                      ? AppColors.positive
                                      : AppColors.negative
                                : AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ValueRow(
            tr(context, 'available'),
            '${account.connected ? account.available.toStringAsFixed(2) : '0.00'} USDT',
            size: 9,
          ),
          const SizedBox(height: 8),
          if (marketOrder)
            Container(
              constraints: const BoxConstraints(minHeight: 68),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.input,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MutedText(tr(context, 'market'), size: 10),
                  const SizedBox(height: 6),
                  Text(
                    quote == null ? '—' : marketNumber(quote.price),
                    style: const TextStyle(fontSize: 14),
                  ),
                  MutedText(tr(context, 'marketPrice'), size: 8),
                ],
              ),
            )
          else
            OrderInput(
              controller: price,
              label: tr(context, 'price'),
              unit: 'USDT',
              fieldKey: 'price-input',
              onChanged: (_) => setState(() => error = null),
              trailing: InkWell(
                onTap: () {
                  if (quote != null) {
                    price.text = marketInput(quote.price);
                    setState(() {});
                  }
                },
                child: Text(
                  tr(context, 'midPrice'),
                  style: const TextStyle(fontSize: 10, color: AppColors.accent),
                ),
              ),
            ),
          const SizedBox(height: 8),
          OrderInput(
            controller: quantity,
            label: tr(context, 'quantity'),
            unit: base,
            fieldKey: 'quantity-input',
            onChanged: (_) => setState(() {
              error = null;
              fraction = 0;
            }),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              inactiveTrackColor: AppColors.line,
              activeTickMarkColor: AppColors.accent,
              inactiveTickMarkColor: AppColors.muted,
            ),
            child: Slider(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              value: fraction,
              divisions: 4,
              label: '${(fraction * 100).round()}%',
              onChanged: account.connected ? allocate : null,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MutedText('${(fraction * 100).round()}%', size: 9),
              const MutedText('100%', size: 9),
            ],
          ),
          const SizedBox(height: 12),
          ValueRow(tr(context, 'orderValue'), '${draft.notional.toStringAsFixed(2)} USDT', size: 9),
          ValueRow(tr(context, 'margin'), '${draft.margin.toStringAsFixed(2)} USDT', size: 9),
          const SizedBox(height: 8),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                tr(context, error!),
                key: const Key('order-error'),
                style: const TextStyle(color: AppColors.negative, fontSize: 11, height: 1.6),
              ),
            ),
          FilledButton(
            key: const Key('submit-order'),
            style: FilledButton.styleFrom(
              backgroundColor: buy ? AppColors.positive : AppColors.negative,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            onPressed: quote == null || quote.offline ? null : submit,
            child: Text(
              tr(
                context,
                account.connected
                    ? buy
                          ? 'buy'
                          : 'sell'
                    : 'connect',
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 32,
                child: Checkbox(
                  value: reduceOnly,
                  side: const BorderSide(color: AppColors.muted),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) => setState(() => reduceOnly = v ?? false),
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  tr(context, 'reduceOnly'),
                  style: const TextStyle(fontSize: 10, color: AppColors.secondary),
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          ValueRow(tr(context, 'fees'), '${draft.fee.toStringAsFixed(4)} USDT', size: 9),
          Text(
            tr(context, account.connected ? 'demoActive' : 'feeHint'),
            style: TextStyle(
              fontSize: 8,
              color: account.connected ? AppColors.warning : AppColors.muted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
