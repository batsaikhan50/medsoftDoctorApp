import 'package:flutter/foundation.dart';
import 'package:medsoft_doctor/api/base_dao.dart';
import 'package:medsoft_doctor/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

//Байршил солилцох үйлдлийн DAO
class MapDAO extends BaseDAO {
  //Түргэн тусмалжийн жагсаалт дуудах
  Future<ApiResponse<List<dynamic>>> getPatientsListAmbulance() {
    return get<List<dynamic>>(
      '${Constants.appUrl}/room/get/driver',
      config: const RequestConfig(
        headerType: HeaderType.xtokenAndTenantAndxmedsoftToken,
        excludeToken: true,
      ),
    );
  }

  //Яаралтай тусламжийн жагсаалт дуудах
  Future<ApiResponse<List<dynamic>>> getPatientsListEmergency(
    List<String> body,
    String dateFrom,
    String dateTo,
  ) {
    return post<List<dynamic>>(
      '${Constants.runnerUrl}/gateway/general/post/api/inpatient/emergency/getAllEmergencies/bydate?datefrom=$dateFrom&dateto=$dateTo',
      config: const RequestConfig(
        headerType: HeaderType.xtokenAndTenantAndxmedsoftToken,
        excludeToken: false,
      ),
      body: body,
    );
  }

  //Үйлдэл дуусгах хүсэлт Апп-р явуулах
  Future<ApiResponse<void>> requestDoneByApp(String roomId) {
    final url = '${Constants.appUrl}/done_request_app/?roomId=$roomId';
    debugPrint('[DEBUG] requestDoneByOTP url: $url');
    return get<void>(
      '${Constants.appUrl}/room/done_request_app/?roomId=$roomId',
      config: const RequestConfig(
        headerType: HeaderType.xtokenAndTenantAndxmedsoftToken,
        excludeToken: false,
      ),
    );
  }

  //Үйлдэл дуусгах хүсэлт OTP-р явуулах
  Future<ApiResponse<void>> requestDoneByOTP(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final tenant = prefs.getString('X-Tenant') ?? '';
    final url = '${Constants.appUrl}/room/done_request_otp?roomId=$roomId';
    debugPrint('[DEBUG] requestDoneByOTP url: $url');
    debugPrint('[DEBUG] requestDoneByOTP X-Tenant: $tenant');
    return get<void>(
      url,
      config: const RequestConfig(
        headerType: HeaderType.xtokenAndTenantAndxmedsoftToken,
        excludeToken: false,
      ),
    );
  }

  //Үйлдлийг OTP-р дуусгах
  Future<ApiResponse<void>> doneByOTP(Map<String, dynamic> body) {
    return post<void>(
      '${Constants.appUrl}/room/done',
      config: const RequestConfig(
        headerType: HeaderType.xtokenAndTenantAndxmedsoftToken,
        excludeToken: false,
      ),
      body: body,
    );
  }
}
