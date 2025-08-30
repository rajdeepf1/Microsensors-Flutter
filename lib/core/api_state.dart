// core/api_state.dart
sealed class ApiState<T> {
  const ApiState();
}

class ApiLoading<T> extends ApiState<T> {
  const ApiLoading();
}

class ApiData<T> extends ApiState<T> {
  final T data;
  const ApiData(this.data);
}

class ApiError<T> extends ApiState<T> {
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const ApiError(this.message, {this.error, this.stackTrace});
}
