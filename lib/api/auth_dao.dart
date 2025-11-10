import 'package:doctor_app/api/base_dao.dart';
import 'package:doctor_app/constants.dart';
import 'package:flutter/material.dart';

//Нэвтрэх, бүртгүүлэх DAO
class AuthDAO extends BaseDAO {
  //Бүх эмнэлгүүдийг дуудах - Login
  Future<ApiResponse<List<dynamic>>> getHospitals() {
    return get<List<dynamic>>(
      '${Constants.runnerUrl}/gateway/servers',
      config: const RequestConfig(headerType: HeaderType.xToken),
    );
  }

  //Бүртгүүлэх
  // Future<ApiResponse<Map<String, dynamic>>> register(Map<String, dynamic> body) {
  //   return post<Map<String, dynamic>>(
  //     '${Constants.appUrl}/auth/signup',
  //     body: body,
  //     config: const RequestConfig(headerType: HeaderType.jsonOnly, excludeToken: true),
  //   );
  // }

  //Нэвтрэх
  Future<ApiResponse<Map<String, dynamic>>> login(Map<String, dynamic> body) {
    debugPrint(HeaderType.xTokenAndTenant.toString());
    return post<Map<String, dynamic>>(
      '${Constants.runnerUrl}/gateway/auth',
      body: body,
      config: const RequestConfig(headerType: HeaderType.xTokenAndTenant, excludeToken: true),
    );
  }

  //QR хүлээх
  //   Uri.parse('${Constants.runnerUrl}/gateway/general/get/api/auth/qr/wait?id=$token'),
  Future<ApiResponse<Map<String, dynamic>>> waitQR(String token) {
    return get<Map<String, dynamic>>(
      '${Constants.runnerUrl}/gateway/general/get/api/auth/qr/wait?id=$token',
      config: const RequestConfig(headerType: HeaderType.xtokenAndTenantAndxMedsoftToken),
    );
  }

  // QR баталгаажуулах
  Future<ApiResponse<Map<String, dynamic>>> claimQR(String token) {
    return get<Map<String, dynamic>>(
      '${Constants.runnerUrl}/gateway/general/get/api/auth/qr/claim?id=$token',
      config: const RequestConfig(headerType: HeaderType.bearerAndJson),
    );
  }

  //Нууц үг сэргээх OTP илгээх
  Future<ApiResponse<Map<String, dynamic>>> sendResetPassOTP(Map<String, dynamic> body) {
    return post<Map<String, dynamic>>(
      '${Constants.appUrl}/auth/otp',
      body: body,
      config: const RequestConfig(headerType: HeaderType.jsonOnly, excludeToken: true),
    );
  }

  //Нууц үг сэргээх
  Future<ApiResponse<Map<String, dynamic>>> resetPassword(Map<String, dynamic> body) {
    return post<Map<String, dynamic>>(
      '${Constants.appUrl}/auth/reset/password',
      body: body,
      config: const RequestConfig(headerType: HeaderType.jsonOnly, excludeToken: true),
    );
  }

  //ДАН-с мэдээлэл дуудах
  Future<ApiResponse<Map<String, dynamic>>> getPatientInfo() {
    return get<Map<String, dynamic>>(
      '${Constants.appUrl}/patient/profile',
      config: const RequestConfig(headerType: HeaderType.bearerToken),
    );
  }
}
