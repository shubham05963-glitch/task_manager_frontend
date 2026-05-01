import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/services/notification_service.dart';
import 'package:frontend/core/services/sp_service.dart';
import 'package:frontend/features/auth/repository/auth_local_repository.dart';
import 'package:frontend/features/auth/repository/auth_remote_repository.dart';
import 'package:frontend/models/user_model.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitial());

  final authRemoteRepository = AuthRemoteRepository();
  final authLocalRepository = AuthLocalRepository();
  final spService = SpService();
  final notificationService = NotificationService();

  // AUTO LOGIN
  Future<void> getUserData() async {
    try {
      final user = await authLocalRepository.getUser();

      // show cached user immediately
      if (user != null) {
        emit(AuthLoggedIn(user));
      }

      // validate token in background
      final userModel = await authRemoteRepository.getUserData();

      if (userModel != null) {
        await authLocalRepository.insertUser(userModel);
        emit(AuthLoggedIn(userModel));
      } else {
        // Only emit AuthInitial if we don't even have a local user
        if (user == null) {
          emit(AuthInitial());
        }
      }
    } catch (e) {
      // If error occurs, keep current state if we have a local user
      final user = await authLocalRepository.getUser();
      if (user == null) {
        emit(AuthInitial());
      }
    }
  }

  // SIGNUP
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      emit(AuthLoading());

      final verifiedEmail = await authRemoteRepository.signUp(
        name: name,
        email: email,
        password: password,
      );

      emit(AuthOtpSent(email: verifiedEmail));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    try {
      emit(AuthLoading());
      await authRemoteRepository.verifyEmailOtp(email: email, otp: otp);
      emit(AuthActionSuccess("Email verified successfully. Please login."));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> resendVerificationOtp({
    required String email,
  }) async {
    try {
      emit(AuthLoading());
      await authRemoteRepository.resendVerificationOtp(email: email);
      emit(AuthOtpSent(email: email));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> forgotPassword({
    required String email,
  }) async {
    try {
      emit(AuthLoading());
      await authRemoteRepository.forgotPassword(email: email);
      emit(AuthOtpSent(email: email, isResetPassword: true));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      emit(AuthLoading());
      await authRemoteRepository.resetPassword(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );
      emit(AuthActionSuccess("Password reset successful. Please login."));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  // LOGIN (FAST RESPONSE)
  Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      emit(AuthLoading());

      final userModel = await authRemoteRepository.login(
        email: email,
        password: password,
      );

      // save token
      if (userModel.token.isNotEmpty) {
        await spService.setToken(userModel.token);
      }

      // cache user locally
      await authLocalRepository.insertUser(userModel);

      emit(AuthLoggedIn(userModel));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  // LOGOUT
  Future<void> logout() async {
    try {
      // Clear all scheduled notifications on logout
      await notificationService.cancelAllNotifications();

      // remove token
      await spService.setToken("");

      // remove user from local database
      await authLocalRepository.deleteUser();

      // reset state
      emit(AuthInitial());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  // UPDATE PROFILE PIC
  Future<void> updateProfilePic(File image) async {
    final currentState = state;
    UserModel? previousUser;
    
    if (currentState is AuthLoggedIn) {
      previousUser = currentState.user;
    } else if (currentState is AuthLoading) {
      previousUser = currentState.user;
    } else if (currentState is AuthError) {
      previousUser = currentState.user;
    }

    if (previousUser == null) return;

    try {
      emit(AuthLoading(user: previousUser));
      
      final updatedUser = await authRemoteRepository.updateProfilePic(
        image: image,
        token: previousUser.token,
      );
      await authLocalRepository.insertUser(updatedUser);
      emit(AuthLoggedIn(updatedUser));
    } catch (e) {
      emit(AuthError(e.toString(), user: previousUser));
    }
  }

  // DELETE PROFILE PIC
  Future<void> deleteProfilePic() async {
    final currentState = state;
    UserModel? previousUser;

    if (currentState is AuthLoggedIn) {
      previousUser = currentState.user;
    } else if (currentState is AuthLoading) {
      previousUser = currentState.user;
    } else if (currentState is AuthError) {
      previousUser = currentState.user;
    }

    if (previousUser == null) return;

    try {
      emit(AuthLoading(user: previousUser));

      final updatedUser = await authRemoteRepository.deleteProfilePic(
        token: previousUser.token,
      );
      await authLocalRepository.insertUser(updatedUser);
      emit(AuthLoggedIn(updatedUser));
    } catch (e) {
      emit(AuthError(e.toString(), user: previousUser));
    }
  }
}
