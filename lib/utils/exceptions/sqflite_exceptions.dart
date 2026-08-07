class SqfliteDbExceptions implements Exception {
  final String code;
  final String? rawMessage;

  SqfliteDbExceptions(this.code, {this.rawMessage});

  factory SqfliteDbExceptions.fromException(Object e) {
    final msg = e.toString().toLowerCase();

    if (msg.contains('no such table')) {
      return SqfliteDbExceptions('NO_TABLE');
    }

    if (msg.contains('no such column')) {
      return SqfliteDbExceptions('NO_COLUMN');
    }

    if (msg.contains('unique constraint failed')) {
      return SqfliteDbExceptions('UNIQUE_FAILED');
    }

    if (msg.contains('not null constraint failed')) {
      return SqfliteDbExceptions('NULL_FAILED');
    }

    if (msg.contains('foreign key constraint failed')) {
      return SqfliteDbExceptions('FOREIGN_KEY_FAILED');
    }

    if (msg.contains('database is locked')) {
      return SqfliteDbExceptions('DB_LOCKED');
    }

    if (msg.contains('disk i/o error')) {
      return SqfliteDbExceptions('DISK_ERROR');
    }

    if (msg.contains('syntax error')) {
      return SqfliteDbExceptions('SYNTAX_ERROR');
    }

    return SqfliteDbExceptions('UNKNOWN', rawMessage: e.toString());
  }

  String get message {
    switch (code) {
      case 'NO_TABLE':
        return 'Database not initialized properly.';
      case 'NO_COLUMN':
        return 'App data structure is outdated. Please update the app.';
      case 'UNIQUE_FAILED':
        return 'This record already exists.';
      case 'NULL_FAILED':
        return 'Missing required information.';
      case 'FOREIGN_KEY_FAILED':
        return 'This action is linked to another record and cannot be completed.';
      case 'DB_LOCKED':
        return 'Database is busy. Please try again.';
      case 'DISK_ERROR':
        return 'Device storage issue. Please free up space.';
      case 'SYNTAX_ERROR':
        return 'Local database query error.';
      default:
        return rawMessage ?? 'Unknown local database error (code: $code)';
    }
  }
}
