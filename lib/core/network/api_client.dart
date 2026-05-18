import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

class ApiClient {
  final Dio dio;

  ApiClient(this.dio) {
    dio.options.baseUrl = AppConstants.apiBaseUrl;
  }
}