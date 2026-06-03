class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.missingScope});

  final String message;
  final int? statusCode;
  final String? missingScope;

  bool get isCollectionViewDenied =>
      statusCode == 403 && (missingScope == 'collection:view' || message.contains('collection:view'));

  @override
  String toString() => message;
}
