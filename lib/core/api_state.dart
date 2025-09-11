// core/api_state.dart
sealed class ApiState<T> {
  const ApiState();
}

/// When no API call has been made yet (idle state)
class ApiInitial<T> extends ApiState<T> {
  const ApiInitial();
}

/// When a request is in progress
class ApiLoading<T> extends ApiState<T> {
  const ApiLoading();
}

/// When request succeeded with data
class ApiData<T> extends ApiState<T> {
  final T data;
  const ApiData(this.data);
}

/// When request failed
class ApiError<T> extends ApiState<T> {
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const ApiError(this.message, {this.error, this.stackTrace});
}
