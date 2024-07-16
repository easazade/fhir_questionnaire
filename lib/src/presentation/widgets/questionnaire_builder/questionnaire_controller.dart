import 'package:fhir/r4.dart';
import 'package:fhir/r4/r4.dart';
import 'package:fhir_questionnaire/src/logic/questionnaire_logic.dart';
import 'package:fhir_questionnaire/src/model/questionnaire_item_bundle.dart';
import 'package:fhir_questionnaire/src/model/questionnaire_item_enable_when_controller.dart';
import 'package:fhir_questionnaire/src/presentation/localization/questionnaire_base_localization.dart';
import 'package:fhir_questionnaire/src/presentation/localization/questionnaire_localization.dart';
import 'package:fhir_questionnaire/src/presentation/utils/flutter_view_utils.dart';
import 'package:fhir_questionnaire/src/presentation/widgets/questionnaire_builder/submit_result.dart';
import 'package:fhir_questionnaire/src/presentation/widgets/questionnaire_item/base/questionnaire_item_view.dart';
import 'package:flutter/widgets.dart';

class QuestionnaireController extends ChangeNotifier {
  QuestionnaireController({
    required this.questionnaire,
    this.onAttachmentLoaded,
    this.localizations,
    this.defaultLocalization,
    this.locale,
    this.onSubmit,
    this.overrideQuestionnaireItemMapper,
    this.signatureImage,
  }) : itemBundles = QuestionnaireLogic.buildQuestionnaireItems(
          questionnaire.item,
          onAttachmentLoaded: onAttachmentLoaded,
          overrideQuestionnaireItemMapper: overrideQuestionnaireItemMapper,
        ) {
    String? locale;
    try {
      locale = locale ??
          FlutterViewUtils.get().platformDispatcher.locale.languageCode;
    } catch (_) {}

    QuestionnaireLocalization.instance.init(
      defaultLocalization: defaultLocalization,
      localizations: localizations,
      locale: locale,
    );

    notifyListeners();
  }

  QuestionnaireItemView? Function(
    QuestionnaireItem questionnaireItem,
    Future<Attachment?> Function()? onAttachmentLoaded,
    QuestionnaireItemEnableWhenController? enableWhenController,
  )? overrideQuestionnaireItemMapper;

  final List<QuestionnaireItemBundle> itemBundles;

  /// Get the QuestionnaireResponse once the user taps on Submit button.
  final ValueChanged<SubmitResult>? onSubmit;

  final Questionnaire questionnaire;

  /// Indicates what should be the fallback localization if locale is not
  /// supported.
  /// Defaults to English
  final QuestionnaireBaseLocalization? defaultLocalization;

  /// Indicates the definition of extra supported localizations.
  /// By default Spanish and English are supported, but you can set
  /// other localizations on this List to be considered.
  final List<QuestionnaireBaseLocalization>? localizations;

  /// The expected locale to show, by default Platform locale is used.
  final String? locale;

  /// Base64Encode image of user signature
  String? signatureImage;

  /// Necessary callback when Questionnaire has items of type = `attachment`
  /// so the logic of loading an Attachment is handled outside of the logic
  /// of QuestionnaireView
  final Future<Attachment?> Function()? onAttachmentLoaded;

  /// tries to validate the answers to each questionnaire item if there is
  /// any invalid answers they will be returned otherwise null will be returned.
  ///
  /// the result is a Map<int, QuestionnaireItemBundle> a questionnaire item bundle
  /// is mapped by its index value that it is indexed in all bundleItems that exists
  /// in this [QuestionnaireController].
  ///
  /// if [notify] is set to true the questionnaire item widgets will be notified
  /// and updated with error message.
  Map<int, QuestionnaireItemBundle> validate({bool notify = true}) {
    final map = <int, QuestionnaireItemBundle>{};

    for (var i = 0; i < itemBundles.length; i++) {
      final questionnaireItemBundle = itemBundles[i];
      if (!questionnaireItemBundle.controller.validate(notify: notify)) {
        map[i] = questionnaireItemBundle;
      }
    }

    notifyListeners();
    return map;
  }

  void setSignatureImage(String base64EncodeImage) {
    signatureImage = base64EncodeImage;
    notifyListeners();
  }

  QuestionnaireResponse _attachSignatureImageToQuestionnaireResponse(
    QuestionnaireResponse questionnaireResponse,
  ) {
    if (signatureImage != null) {
      final responseSignatureUrl = FhirUri(
        'http://hl7.org/fhir/StructureDefinition/questionnaireresponse-signature',
      );

      final extensions = questionnaireResponse.extension_?.toList()
        ?..removeWhere(
          (final element) => element.url == responseSignatureUrl,
        );

      questionnaireResponse = questionnaireResponse.copyWith(
        extension_: extensions
          ?..add(
            FhirExtension(
              url: FhirUri(responseSignatureUrl),
              valueAttachment: Attachment(
                contentType: FhirCode('image/data'),
                data: FhirBase64Binary(signatureImage),
              ),
            ),
          ),
      );
    }

    return questionnaireResponse;
  }

  SubmitResult submit() {
    final SubmitResult submitResult;
    final invalidItems = validate();

    if (invalidItems.isEmpty) {
      QuestionnaireResponse questionnaireResponse =
          QuestionnaireLogic.generateResponse(
        questionnaire: questionnaire,
        itemBundles: itemBundles,
      );

      questionnaireResponse = _attachSignatureImageToQuestionnaireResponse(
        questionnaireResponse,
      );

      submitResult = SubmitResult.questionnaireResponse(questionnaireResponse);
    } else {
      submitResult = SubmitResult.invalidItems(invalidItems);
    }

    notifyListeners();
    return submitResult;
  }
}
