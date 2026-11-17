import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/domain/funding_catalog.dart';
import 'package:vanta/features/funding/presentation/funding_selection.dart';

FundingAsset _usdt(int chain) => FundingAsset(
  asset: 'USDT',
  displayName: 'Tether',
  chainId: chain,
  tokenAddress: '0x${'1' * 40}',
  decimals: 6,
  isNative: false,
  routeType: 'normal',
);

void main() {
  final assets = [_usdt(1), _usdt(56), _usdt(42161)];
  late FundingSelection selection;
  setUp(() => selection = FundingSelection());
  tearDown(() => selection.dispose());

  test('starts on a supported default network', () {
    final choice = FundingChoice.of(assets, selection, defaultChain: 42161);
    expect(choice.chainId, 42161);
    expect(choice.asset?.chainId, 42161);
  });

  test('an unsupported or unknown default leaves the network unselected', () {
    expect(FundingChoice.of(assets, selection, defaultChain: 8453).chainId, isNull);
    expect(FundingChoice.of(assets, selection).chainId, isNull);
    expect(FundingChoice.of(assets, selection, defaultChain: 8453).asset, isNull);
  });

  test("the user's pick wins over the default", () {
    selection.select(chainId: 1);
    expect(FundingChoice.of(assets, selection, defaultChain: 56).chainId, 1);
  });
}
