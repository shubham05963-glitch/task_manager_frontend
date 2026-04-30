class Constants {
  static const String _defaultBackendUri =
      "https://task-manager-backend-lff4.onrender.com";

  static final String backendUri = _resolveBackendUri();

  static String _resolveBackendUri() {
    const envApiUrl = String.fromEnvironment("API_URL", defaultValue: "");
    final raw = envApiUrl.isNotEmpty ? envApiUrl : _defaultBackendUri;
    final normalized = raw.trim().replaceAll(RegExp(r"/+$"), "");

    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError("Invalid API_URL/BASE_URL: '$raw'");
    }

    if (uri.scheme != "https") {
      throw StateError("API URL must use HTTPS. Received: '$normalized'");
    }

    if (!uri.host.contains(".")) {
      throw StateError(
        "API host seems incomplete (missing domain): '${uri.host}'",
      );
    }

    if (uri.host == "localhost" || uri.host == "127.0.0.1") {
      throw StateError(
        "Do not use localhost for real devices. Use a public HTTPS API URL.",
      );
    }

    return normalized;
  }
}
