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

  /// SIGN UP
  Future<UserModel> signUp({
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

      final data = jsonDecode(response.body);

      if (response.statusCode != 201) {
        throw Exception(data["error"] ?? "Signup failed");
      }

      return UserModel.fromMap(data);
    } on SocketException {
      throw Exception("No internet connection or server unreachable.");
    } on TimeoutException {
      throw Exception("Server timed out. Please try again.");
    } catch (e) {
      throw Exception(e.toString());
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
        throw Exception(data["error"] ?? "Login failed");
      }

      return UserModel.fromMap(data);
    } on SocketException {
      throw Exception("No internet connection or server unreachable.");
    } on TimeoutException {
      throw Exception("Server timed out. Please try again.");
    } catch (e) {
      throw Exception(e.toString());
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
        throw Exception(jsonDecode(userRes.body)["error"]);
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

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(data["error"] ?? "Failed to update profile picture");
      }

      return UserModel.fromMap(data);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// DELETE PROFILE PICTURE
  Future<UserModel> deleteProfilePic({
    required String token,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse("${Constants.backendUri}/auth/profile-pic"),
        headers: {
          'x-auth-token': token,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(data["error"] ?? "Failed to delete profile picture");
      }

      return UserModel.fromMap(data);
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
