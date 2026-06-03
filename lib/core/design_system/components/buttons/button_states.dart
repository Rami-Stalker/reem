/// Button interaction states for styling.
enum DsButtonState {
  enabled,
  disabled,
  loading,
  pressed,
}

extension DsButtonStateX on DsButtonState {
  bool get isInteractive =>
      this == DsButtonState.enabled || this == DsButtonState.pressed;

  bool get isLoading => this == DsButtonState.loading;
  bool get isDisabled => this == DsButtonState.disabled;
}
