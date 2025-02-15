import 'package:digital_signage/data/response/status.dart';

class ApiResponse<T> {
  Status? status;
  T? data;
  String? message;

  ApiResponse(this.message, this.data, this.status);

  ApiResponse.loading() : status = Status.Loading;
  ApiResponse.success() : status = Status.Success;
  ApiResponse.error() : status = Status.Error;

  @override
  String toString() {
    return "Status: $status/n Message: $message/n Data: $data";
  }
}
