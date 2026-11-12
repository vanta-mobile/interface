import '../../../core/data/personal_signature_verifier.dart';

bool verifyAssistantPersonalSignature(String address, String message, String signature) =>
    verifyPersonalSignature(address, message, signature);
