import 'package:doctor_app/api/base_dao.dart';
import 'package:doctor_app/constants.dart';

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
    return get<void>(
      '${Constants.appUrl}/done_request_app/?roomId=$roomId',
      config: const RequestConfig(
        headerType: HeaderType.xtokenAndTenantAndxmedsoftToken,
        excludeToken: false,
      ),
    );
  }

  //Үйлдэл дуусгах хүсэлт OTP-р явуулах
  Future<ApiResponse<void>> requestDoneByOTP(String roomId) {
    return get<void>(
      '${Constants.appUrl}/done_request_otp/?roomId=$roomId',
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
