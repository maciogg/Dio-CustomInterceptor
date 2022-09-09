import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

class CustomInterceptor extends Interceptor {
  Ref ref;
  bool isAuth;
  CustomInterceptor({
    required this.ref,
    required this.isAuth,
  });

  // ------------------------------------------------------------------------
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.connectTimeout = 5000;
    options.receiveTimeout = 5000;
    if (isAuth) {
      String token = ref.watch(userProvider).state.token ?? "";
      options.headers["Authorization"] = 'Basic ${base64.encode(utf8.encode('$token:'))}';
    }
    return super.onRequest(options, handler);
  }

  // ------------------------------------------------------------------------
  @override
  void onError(DioError err, ErrorInterceptorHandler handler) async {
    // Hide spinner
    EasyLoading.dismiss();

    // Auth Error Handle
    if (isAuth && (err.response?.statusCode == 401 || err.response?.statusCode == 403)) {
      // refresh token
      String newToken = await _refreshToken();
      // retry call
      RequestOptions requestOptions = err.requestOptions;
      final opts = Options(method: requestOptions.method);
      var options = err.response!.requestOptions;

      try {
        Dio dioRecall = Dio();
        dioRecall.options.connectTimeout = 5000;
        dioRecall.options.receiveTimeout = 5000;
        dioRecall.options.headers["Authorization"] = 'Basic ${base64.encode(utf8.encode('$newToken:'))}';
        dioRecall.interceptors.add(LogInterceptor(responseBody: false));
        final response = await dioRecall.request(options.path,
            options: opts,
            cancelToken: options.cancelToken,
            onReceiveProgress: options.onReceiveProgress,
            data: options.data,
            queryParameters: options.queryParameters);
        handler.resolve(response);
      } catch (e) {
        if (e is DioError) {
          // logout
          EasyLoading.dismiss();
          await AppAlert.oneButtonAlert("api_error_session_expired_title".tr(), "api_error_session_expired_message".tr(), 'app_done'.tr(), AlertType.none);
          ref.read(userProvider).set(User.initGuest());
          SP.setUserToStorage(User.initGuest());
          navKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
          ref.read(userDataProvider).clean();
        }
      }
      return;
    }

    // Other Errors Handle
    String errorMessage = "";
    // ---------------- 400 ----------------
    if (err.response?.statusCode == 400) {
      errorMessage = "api_error_bad_login_credentials".tr();
      // ---------------- 401 ----------------
    } else if (err.response?.statusCode == 401) {
      errorMessage = "api_error_401".tr();
      // ---------------- 404 ----------------
    } else if (err.response?.statusCode == 404) {
      errorMessage = "api_error_404".tr();
      // ---------------- 409 ----------------
    } else if (err.response?.statusCode == 409) {
      errorMessage = "api_error_404".tr();
      // ---------------- connect Timeout ----------------
    } else if (err.type == DioErrorType.connectTimeout) {
      errorMessage = "api_error_connection_timeout".tr();
      // ---------------- receive Timeout ----------------
    } else if (err.type == DioErrorType.receiveTimeout) {
      errorMessage = "api_error_receive_timeout".tr();
      // ---------------- other ----------------
    } else {
      errorMessage = err.response?.toString().replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ') ?? "";
    }
    await AppAlert.oneButtonAlert(
        'Error', errorMessage, 'app_done'.tr(), AlertType.none);
  }

  // ------------------------------------------------------------------------
  Future<String> _refreshToken() async {
   // your refresh token function
  }
}
