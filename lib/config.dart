class FindinConfig {
  final bool isConsoleColorsEnabled;
  final bool isVerboseModeEnabled;

  const FindinConfig({
    this.isConsoleColorsEnabled = true,
    this.isVerboseModeEnabled = false,
  });

  FindinConfig copyWith({
    bool? isConsoleColorsEnabled,
    bool? isVerboseModeEnabled,
  }) {
    return FindinConfig(
      isConsoleColorsEnabled:
          isConsoleColorsEnabled ?? this.isConsoleColorsEnabled,
      isVerboseModeEnabled: isVerboseModeEnabled ?? this.isVerboseModeEnabled,
    );
  }

  static FindinConfig main = const FindinConfig();
}
