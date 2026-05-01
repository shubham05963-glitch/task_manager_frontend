import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:frontend/core/constants/constants.dart';
import 'package:frontend/core/services/sp_service.dart';
import 'package:frontend/features/auth/repository/auth_local_repository.dart';
import 'package:frontend/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class AuthRemoteRepository {
  final SpService spService = SpService();
  final AuthLocalRepository authLocalRepository = AuthLocalRepository();

  String _responseError(http.Response res, String fallback) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic> && body["error"] != null) {
        return body["error"].toString();
      }
    } catch (_) {}
    return fallback;
  }

  /// SIGN UP
  Future<String> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse("${Constants.backendUri}/auth/signup"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "name": name,
          "email": email,
          "password": password,
        }),
      )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode != 201) {
        throw _responseError(response, "Signup failed (${response.statusCode})");
      }

      final data = jsonDecode(response.body);
      return (data["email"] ?? email).toString();
    } on SocketException {
      throw "No internet connection or server unreachable.";
    } on TimeoutException {
      throw "Server timed out. Please try again.";
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse("${Constants.backendUri}/auth/verify-email"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "otp": otp}),
      )
          .timeout(const Duration(seconds: 40));
      if (response.statusCode != 200) {
        throw _responseError(response, "OTP verification failed");
      }
    } on SocketException {
      throw "No internet connection or server unreachable.";
    } on TimeoutException {
      throw "Server timed out. Please try again.";
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> resendVerificationOtp({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse("${Constants.backendUri}/auth/resend-verification-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      )
          .timeout(const Duration(seconds: 40));
      if (response.statusCode != 200) {
        throw _responseError(response, "Failed to resend verification OTP");
      }
    } on SocketException {
      throw "No internet connection or server unreachable.";
    } on TimeoutException {
      throw "Server timed out. Please try again.";
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> forgotPassword({required String email}) async {
    try {
      final response = await http
          .post(
        Uri.parse("${Constants.backendUri}/auth/forgot-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      )
          .timeout(const Duration(seconds: 40));
      if (response.statusCode != 200) {
        throw _responseError(response, "Failed to send reset OTP");
      }
    } on SocketException {
      throw "No internet connection or server unreachable.";
    } on TimeoutException {
      throw "Server timed out. Please try again.";
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse("${Constants.backendUri}/auth/reset-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(
          {"email": email, "otp": otp, "newPassword": newPassword},
        ),
      )
          .timeout(const Duration(seconds: 40));
      if (response.statusCode != 200) {
        throw _responseError(response, "Failed to reset password");
      }
    } on SocketException {
      throw "No internet connection or server unreachable.";
    } on TimeoutException {
      throw "Server timed out. Please try again.";
    } catch (e) {
      throw e.toString();
    }
  }

  /// LOGIN
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse("${Constants.backendUri}/auth/login"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      )
          .timeout(const Duration(seconds: 40));

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw _responseError(response, "Login failed (${response.statusCode})");
      }

      return UserModel.fromMap(data);
    } on SocketException {
      throw "No internet connection or server unreachable.";
    } on TimeoutException {
      throw "Server timed out. Please try again.";
    } catch (e) {
      throw e.toString();
    }
  }

  /// AUTO LOGIN
  Future<UserModel?> getUserData() async {
    try {
      final token = await spService.getToken();

      if (token == null || token.isEmpty) {
        return null;
      }

      /// CHECK TOKEN
      final tokenRes = await http
          .post(
        Uri.parse("${Constants.backendUri}/auth/tokenIsValid"),
        headers: {
          "Content-Type": "application/json",
          "x-auth-token": token,
        },
      )
          .timeout(const Duration(seconds: 40));

      if (tokenRes.statusCode != 200 || jsonDecode(tokenRes.body) == false) {
        return null;
      }

      /// GET USER DATA
      final userRes = await http
          .get(
        Uri.parse("${Constants.backendUri}/auth"),
        headers: {
          "Content-Type": "application/json",
          "x-auth-token": token,
        },
      )
          .timeout(const Duration(seconds: 40));

      if (userRes.statusCode != 200) {
        throw jsonDecode(userRes.body)["error"];
      }

      final data = jsonDecode(userRes.body);

      return UserModel.fromMap(data);
    } catch (e) {
      print("AUTO LOGIN ERROR: $e");

      /// fallback to local storage
      final user = await authLocalRepository.getUser();
      return user;
    }
  }

  /// UPDATE PROFILE PICTURE
  Future<UserModel> updateProfilePic({
    required File image,
    required String token,
  }) async {
    try {
      // Note: If this still gives "Route not found", verify if the backend route is correct.
      // Some backends use /auth/profile-picture or /auth/profile
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("${Constants.backendUri}/auth/profile-pic"),
      );

      request.headers.addAll({
        'x-auth-token': token,
      });

      request.files.add(
        await http.MultipartFile.fromPath(
          'profilePic',
          image.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 40));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw _responseError(
          response,
          "Failed to update profile picture (${response.statusCode})",
        );
      }

      final data = jsonDecode(response.body);
      return UserModel.fromMap(data);
    } on SocketException {
      throw "No internet connection or server unreachable.";
    } on TimeoutException {
      throw "Server timed out. Please try again.";
    } on FormatException {
      throw "Server returned invalid response format.";
    } catch (e) {
      throw e.toString();
    }
  }

  /// DELETE PROFILE PICTURE
  Future<UserModel> deleteProfilePic({
    required String token,
  }) async {
    try {
      final response = await http
          .delete(
            Uri.parse("${Constants.backendUri}/auth/profile-pic"),
            headers: {
              'x-auth-token': token,
            },
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode != 200) {
        throw _responseError(
          response,
          "Failed to delete profile picture (${response.statusCode})",
        );
      }

      final data = jsonDecode(response.body);
      return UserModel.fromMap(data);
    } on SocketException {
      throw "No internet connection or server unreachable.";
    } on TimeoutException {
      throw "Server timed out. Please try again.";
    } on FormatException {
      throw "Server returned invalid response format.";
    } catch (e) {
      throw e.toString();
    }
  }
}
