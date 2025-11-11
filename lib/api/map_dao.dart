import 'package:doctor_app/api/base_dao.dart';
import 'package:doctor_app/constants.dart';

//Байршил солилцох үйлдлийн DAO
class MapDAO extends BaseDAO {
  //Өрөөний мэдээлэл авах
  Future<ApiResponse<List<dynamic>>> getPatientsListAmbulance() {
    return get<List<dynamic>>(
      '${Constants.appUrl}/room/get/driver',
      config: const RequestConfig(
        headerType: HeaderType.xtokenAndTenantAndxmedsoftToken,
        excludeToken: true,
      ),
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
