void validateFormat(bool expression, String message) {
  if (expression) return;
  throw FormatException(message);
}
