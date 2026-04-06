enum CbOptionType {
  flag,
  number,
  text,
  json,
}

class CbError implements Exception {
  final String type;
  final String? message;

  CbError(this.type, {this.message});

  @override
  String toString() => 'CbError: $type${message != null ? ' - $message' : ''}';
}
