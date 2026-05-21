import '../models/distribution_obj.dart';
import 'percentage_bucketing.dart';

class ModifierEvaluator {
  static bool evaluate(
    ContentModifier modifier,
    String visitorId,
    List<Map<String, String>> contextAssignments,
  ) {
    switch (modifier.type) {
      case 'PERCENTAGE_HASH':
        final args = modifier.args ?? {};
        final hashInput = args['hashInput'] as String?;
        String? input;
        if (hashInput == 'VISITOR') {
          input = visitorId;
        } else if (hashInput == 'ASSIGNMENT') {
          final assignmentKey = args['assignmentKey'] as String?;
          input = contextAssignments
              .where((a) => a['key'] == assignmentKey)
              .map((a) => a['value'])
              .firstOrNull;
        } else {
          return false;
        }
        if (input == null) return false;
        final salt = args['salt'] as String? ?? '';
        final percentage = args['percentage'] as num;
        return isInPercentageBucket(input, percentage, salt: salt);

      case 'ASSIGNMENT_MATCH':
        final args = modifier.args ?? {};
        final key = args['key'] as String?;
        final value = args['value'] as String?;
        final keyIn = (args['key-in'] as List?)?.cast<String>();
        final valueIn = (args['value-in'] as List?)?.cast<String>();
        if (key != null &&
            !contextAssignments.any((a) => a['key'] == key)) return false;
        if (value != null &&
            contextAssignments
                    .where((a) => a['key'] == key)
                    .map((a) => a['value'])
                    .firstOrNull !=
                value) return false;
        if (keyIn != null &&
            !contextAssignments.any((a) => keyIn.contains(a['key'])))
          return false;
        if (valueIn != null &&
            !valueIn.contains(contextAssignments
                .where((a) => a['key'] == key)
                .map((a) => a['value'])
                .firstOrNull)) return false;
        return true;

      case 'MATCH_ANY':
        return modifier.conditions
                ?.any((c) => evaluate(c, visitorId, contextAssignments)) ??
            false;

      case 'MATCH_ALL':
        return modifier.conditions
                ?.every((c) => evaluate(c, visitorId, contextAssignments)) ??
            false;

      default:
        return false;
    }
  }
}
