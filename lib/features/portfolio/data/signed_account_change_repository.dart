import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/account_change_stream.dart';
import '../domain/account_snapshot.dart';
import 'aster_account_service.dart';
import 'aster_spot_service.dart';
import 'aster_user_stream.dart';
import 'signed_account_request.dart';

class SignedAccountChangeRepository implements AccountChangeRepository {
  SignedAccountChangeRepository(
    AsterAccountService service,
    AccountRequestSigner sign, {
    AsterReadNonces? nonces,
    DateTime Function()? now,
    WebSocketChannel Function(Uri)? connect,
  }) : _request = SignedAccountRequest(
         serverTime: service.serverTime,
         send: service.userStream,
         sign: sign,
         nonces: nonces,
       ),
       _now = now ?? DateTime.now,
       _connect = connect ?? WebSocketChannel.connect,
       _spot = false;

  SignedAccountChangeRepository.spot(
    AsterSpotService service,
    AccountRequestSigner sign, {
    AsterReadNonces? nonces,
    DateTime Function()? now,
    WebSocketChannel Function(Uri)? connect,
  }) : _request = SignedAccountRequest(
         serverTime: service.serverTime,
         send: service.userStream,
         sign: sign,
         nonces: nonces,
       ),
       _now = now ?? DateTime.now,
       _connect = connect ?? WebSocketChannel.connect,
       _spot = true;
  final SignedAccountRequest _request;
  final bool _spot;
  final DateTime Function() _now;
  final WebSocketChannel Function(Uri) _connect;
  String? _key;
  DateTime? _expiresAt;
  int _generation = 0;

  @override
  Future<DateTime> authorize({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    clear();
    final generation = _generation;
    final started = _now();
    final data = await _request.read(
      address: address,
      isCurrent: () => generation == _generation && isCurrent(),
      onStep: onStep,
    );
    if (data is! Map<String, dynamic> ||
        data['listenKey'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{16,512}$').hasMatch(data['listenKey'] as String)) {
      throw const AccountReadFailure('accountDataInvalid');
    }
    // Conservative deadline includes clock fetch, signature and HTTP latency.
    final expiresAt = started.add(const Duration(minutes: 60));
    if (!_now().isBefore(expiresAt)) throw const AccountReadFailure('accountSignatureExpired');
    _key = data['listenKey'] as String;
    _expiresAt = expiresAt;
    return expiresAt;
  }

  @override
  Stream<AccountChangeEvent> connect() {
    final key = _key;
    final expiresAt = _expiresAt;
    if (key == null || expiresAt == null || !_now().isBefore(expiresAt)) {
      return Stream.value(const AccountChangeEvent.expired());
    }
    return (_spot ? AsterUserStream.spot(key, _connect) : AsterUserStream(key, _connect)).events;
  }

  @override
  void clear() {
    _generation++;
    _key = null;
    _expiresAt = null;
  }
}
