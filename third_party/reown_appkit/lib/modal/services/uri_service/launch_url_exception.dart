class LaunchUrlException implements Exception {
  final String message;
  LaunchUrlException(this.message);
  @override
  String toString() => message;
}

class CanNotLaunchUrl extends LaunchUrlException {
  CanNotLaunchUrl() : super('App not installed');
}

class ErrorLaunchingUrl extends LaunchUrlException {
  ErrorLaunchingUrl() : super('Error launching app');
}
