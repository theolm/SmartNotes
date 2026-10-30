import 'package:injectable/injectable.dart';
import 'package:smartnotes/data/services/processing_feedback_service.dart';
import 'package:smartnotes/domain/entities/processing_feedback.dart';
import 'package:smartnotes/domain/services/i_formatting_feedback_service.dart';
import 'package:smartnotes/domain/services/i_formatting_model_service.dart';

@LazySingleton(as: IFormattingFeedbackService)
class FormattingFeedbackService implements IFormattingFeedbackService {
  FormattingFeedbackService(this._feedback, this._models);

  final ProcessingFeedbackService _feedback;
  final IFormattingModelService _models;

  @override
  Future<T> run<T>(String entryId, Future<T> Function() operation) async {
    final model = _models.activeModel;
    if (model == null) return operation();
    final job = await _feedback.begin(
      entryId,
      model.name,
      phase: ProcessingPhase.preparingFormatting,
    );
    var failed = true;
    try {
      await _feedback.update(ProcessingPhase.formatting, model.name, job: job);
      final result = await operation();
      failed = false;
      return result;
    } finally {
      await _feedback.finish(job: job, failed: failed);
    }
  }
}
