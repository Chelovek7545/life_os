abstract interface class TelegramSettings {
  String get token;
  String get allowedUsers;
  Future<void> saveToken(String token);
}
