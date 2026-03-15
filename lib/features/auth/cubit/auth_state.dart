part of "auth_cubit.dart";

sealed class AuthState {}

final class AuthInitial extends AuthState {}

final class AuthLoading extends AuthState {
  final UserModel? user;
  AuthLoading({this.user});
}

final class AuthSignUp extends AuthState {}

final class AuthLoggedIn extends AuthState {
  final UserModel user;
  AuthLoggedIn(this.user);
}

final class AuthError extends AuthState {
  final String error;
  final UserModel? user;
  AuthError(this.error, {this.user});
}
