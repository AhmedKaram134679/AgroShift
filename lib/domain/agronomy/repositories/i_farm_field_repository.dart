import 'package:agro_shift/core/error/failures.dart';
import 'package:agro_shift/core/error/result.dart';
import 'package:agro_shift/domain/agronomy/models/farm_field.dart';

/// Provider-independent contract for persistent farm field management.
abstract class IFarmFieldRepository {
  /// Fetches all registered fields (both built-in and user-created).
  Future<Result<List<FarmField>, Failure>> getAllFields();

  /// Saves a new field or updates an existing field.
  Future<Result<void, Failure>> saveField(
    FarmField field, {
    bool isDefault = false,
  });

  /// Deletes a field by its unique ID.
  Future<Result<void, Failure>> deleteField(String id);

  /// Seeds built-in benchmark fields if not already seeded and not deleted by the user.
  Future<Result<void, Failure>> seedDefaultFieldsIfNecessary(
    List<FarmField> defaults,
  );
}
