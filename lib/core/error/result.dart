/// Functional result type representing either a success [T] or a failure [E].
sealed class Result<T, E> {
  const Result();

  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is FailureResult<T, E>;

  T? get dataOrNull => switch (this) {
    Success(data: final d) => d,
    FailureResult() => null,
  };

  E? get failureOrNull => switch (this) {
    Success() => null,
    FailureResult(failure: final f) => f,
  };

  R when<R>({
    required R Function(T data) success,
    required R Function(E failure) failure,
  }) {
    return switch (this) {
      Success(data: final d) => success(d),
      FailureResult(failure: final f) => failure(f),
    };
  }
}

final class Success<T, E> extends Result<T, E> {
  final T data;
  const Success(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T, E> &&
          runtimeType == other.runtimeType &&
          data == other.data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Success($data)';
}

final class FailureResult<T, E> extends Result<T, E> {
  final E failure;
  const FailureResult(this.failure);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FailureResult<T, E> &&
          runtimeType == other.runtimeType &&
          failure == other.failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'FailureResult($failure)';
}
