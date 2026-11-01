/// A persistence failure with its original cause.
class StorageException implements Exception {
  StorageException(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() => message;
}
