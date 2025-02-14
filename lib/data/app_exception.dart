class AppException implements Exception {
  final _message;
  final _prefix;

  AppException([this._message, this._prefix]);
  String toString() {
    return "$_prefix..$_message";
  }
}

class FetalException extends AppException {
  FetalException([String? message])
      : super(message, "Error During Communication");
}

class BadRequestException extends AppException {
  BadRequestException([String? message]) : super(message, "Invalid Request");
}

class UnAuthException extends AppException {
  UnAuthException([String? message]) : super(message, "UnAuthorised");
}

