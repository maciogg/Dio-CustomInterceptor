

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
    // return super.onError(err, handler);
    String errorMessage = "";

    debugPrint("DIO ERROR");
    debugPrint(err.response?.statusCode.toString());
    debugPrint(err.response?.toString());
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
        err.requestOptions.path.substring(startupConfig.currentShop.domain.length + 1), errorMessage, 'app_done'.tr(), AlertType.none);
  }

  // ------------------------------------------------------------------------
  Future<String> _refreshToken() async {
    String refreshedToken;
    var user = await SP.getUserFromStorage();
    var params = {
      "email": user.login,
      "password": user.password,
    };

    try {
      Dio dioToken = Dio();
      dioToken.options.connectTimeout = 5000;
      dioToken.options.receiveTimeout = 5000;
      Response response = await dioToken.post(
        '${startupConfig.currentShop.domain}/api/AuthTokens',
        data: jsonEncode(params),
      );
      if (response.statusCode == 201) {
        // token refreshed
        var result = User.fromMap(response.data);
        refreshedToken = result.token ?? "";
        ref.read(userProvider).setToken(refreshedToken);
        return refreshedToken;
      }
    } catch (e) {
      return "";
    }
    return "";
  }
}
