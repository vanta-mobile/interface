typedef AccountRequestSigner = Future<String> Function({
  required String expectedAddress,
  required Map<String, Object?> typedData,
});

/// The account owner and its authorized request signer are distinct identities.
class AccountRequestIdentity {
  const AccountRequestIdentity({required this.address, required this.sign, this.onRejected});
  final String address;
  final AccountRequestSigner sign;
  final Future<void> Function()? onRejected;
}

typedef AccountRequestAuthorization = Future<AccountRequestIdentity> Function(String owner);
