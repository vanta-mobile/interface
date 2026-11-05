/// Documented Aster futures policies. FOK is not part of this protocol.
enum LiveOrderTimeInForce {
  gtc('GTC'),
  ioc('IOC'),
  postOnly('GTX'),
  hidden('HIDDEN');

  const LiveOrderTimeInForce(this.wire);
  final String wire;
}
