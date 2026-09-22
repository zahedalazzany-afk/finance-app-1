import 'dart:convert';
import 'package:googleapis/drive/v3.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class DriveBackup {
  static const _kAppFolder = 'appDataFolder';

  GoogleSignIn? _signIn;
  DriveApi? _driveApi;

  static const List<String> _scopes = [DriveApi.driveAppdataScope];

  GoogleSignIn _getSignIn() => _signIn ??=
      GoogleSignIn(scopes: _scopes, serverClientId: null);

  Future<DriveApi> _ensureApi() async {
    if (_driveApi != null) return _driveApi!;
    final signIn = _getSignIn();
    if (signIn.currentUser == null) {
      await signIn.signIn();
    }
    if (signIn.currentUser == null) {
      throw Exception('لم يتم تسجيل الدخول إلى Google');
    }
    final client = await signIn.authenticatedClient();
    if (client == null) {
      throw Exception('تعذر الحصول على جلسة الدخول');
    }
    _driveApi = DriveApi(client);
    return _driveApi!;
  }

  Future<void> signOut() async {
    await _signIn?.signOut();
    _driveApi = null;
  }

  bool get isSignedIn {
    final current = _driveApi != null || _signIn?.currentUser != null;
    return current;
  }

  Future<String?> get signedInEmail async {
    final current = _signIn?.currentUser;
    return current?.email;
  }

  /// Uploads the given JSON string as a backup file to the app-only Drive folder.
  /// Returns the new file name (with timestamp) saved in Drive.
  Future<String> uploadBackup(String jsonStr) async {
    final api = await _ensureApi();

    final timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final fileName = 'backup_$timestamp.json';

    final bytes = utf8.encode(jsonStr);
    final media = Media(
      Stream.value(bytes),
      bytes.length,
      contentType: 'application/json',
    );

    final created = await api.files.create(
      File(
        name: fileName,
        parents: [_kAppFolder],
        mimeType: 'application/json',
        createdTime: DateTime.now().toUtc(),
      ),
      uploadMedia: media,
      uploadOptions: UploadOptions.defaultOptions,
    );

    return created.id ?? fileName;
  }

  /// Lists backup files stored in the app-only Drive folder, newest first.
  Future<List<File>> listBackups() async {
    final api = await _ensureApi();
    final response = await api.files.list(
      spaces: _kAppFolder,
      q: "name contains 'backup_' and name contains '.json'",
      orderBy: 'createdTime desc',
    );
    return response.files ?? [];
  }

  /// Downloads a backup by its file id and returns the JSON string.
  Future<String> downloadBackup(String fileId) async {
    final api = await _ensureApi();
    final response = await api.files.get(
      fileId,
      downloadOptions: DownloadOptions.fullMedia,
    );
    final media = response as Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  /// Deletes a backup by its file id.
  Future<void> deleteBackup(String fileId) async {
    final api = await _ensureApi();
    await api.files.delete(fileId);
  }
}
