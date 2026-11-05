/// Aster V3 specifies chain 1666 for account request signatures, independent
/// of the chain used for SIWE. Wallet compatibility/authorization is verified
/// only by a successful signed account response, never by a local signature.
Map<String, Object?> asterReadTypedData(String query) => {
  'types': {
    'EIP712Domain': [
      {'name': 'name', 'type': 'string'},
      {'name': 'version', 'type': 'string'},
      {'name': 'chainId', 'type': 'uint256'},
      {'name': 'verifyingContract', 'type': 'address'},
    ],
    'Message': [
      {'name': 'msg', 'type': 'string'},
    ],
  },
  'primaryType': 'Message',
  'domain': {
    'name': 'AsterSignTransaction',
    'version': '1',
    'chainId': 1666,
    'verifyingContract': '0x0000000000000000000000000000000000000000',
  },
  'message': {'msg': query},
};
