/// Lightweight i18n for the Dataleon KYC SDK.
///
/// Translations are stored as nested maps keyed by language code.
/// Use [t] to look up a dot-separated path, e.g. `t('fr', 'intro.startVerification')`.

class DataleonLocalizations {
  DataleonLocalizations._();

  /// Look up a translation by [lang] and dot-separated [key].
  /// Returns [fallback] (or the key itself) when not found.
  static String t(String lang, String key, {String? fallback, Map<String, String>? params}) {
    final translations = _data[lang] ?? _data['fr']!;
    final result = _resolve(translations, key) ?? _resolve(_data['fr']!, key) ?? fallback ?? key;
    if (params == null || params.isEmpty) return result;
    var output = result;
    params.forEach((k, v) {
      output = output.replaceAll('{{$k}}', v);
    });
    return output;
  }

  static String? _resolve(Map<String, dynamic> map, String key) {
    final parts = key.split('.');
    dynamic current = map;
    for (final part in parts) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current is String ? current : null;
  }

  /// Custom document display name based on language.
  /// Follows React priority: t(doc.label) → displayNameFR/EN → name → t(doc.labelKey) → key
  static String customDocLabel(String lang, Map<String, dynamic> doc) {
    // 1. Try i18n translation of the label field
    final label = doc['label'] as String?;
    if (label != null && label.isNotEmpty) {
      final translated = t(lang, label);
      if (translated != label) return translated;
    }

    // 2. Try displayNameFR / displayNameEN based on language
    if (lang == 'fr') {
      final fr = doc['displayNameFR'] as String?;
      if (fr != null && fr.trim().isNotEmpty) return fr.trim();
      final en = doc['displayNameEN'] as String?;
      if (en != null && en.trim().isNotEmpty) return en.trim();
    } else if (lang == 'en') {
      final en = doc['displayNameEN'] as String?;
      if (en != null && en.trim().isNotEmpty) return en.trim();
      final fr = doc['displayNameFR'] as String?;
      if (fr != null && fr.trim().isNotEmpty) return fr.trim();
    } else {
      // Other languages: try FR first, then EN
      final fr = doc['displayNameFR'] as String?;
      if (fr != null && fr.trim().isNotEmpty) return fr.trim();
      final en = doc['displayNameEN'] as String?;
      if (en != null && en.trim().isNotEmpty) return en.trim();
    }

    // 3. Try name
    final name = doc['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();

    // 4. Try translating labelKey
    final labelKey = doc['labelKey'] as String?;
    if (labelKey != null && labelKey.isNotEmpty) {
      final translated = t(lang, labelKey);
      if (translated != labelKey) return translated;
    }

    // 5. Last resort: key
    return doc['key'] as String? ?? '';
  }

  /// Standard document type mapping: value → labelKey (for enrichment)
  static const standardDocLabelKeys = <String, String>{
    'company_statuts': 'documentListType.company_statuts',
    'rbe': 'documentListType.rbe',
    'nui_entreprise': 'documentListType.nui_entreprise',
    'rccm': 'documentListType.RCCM',
    'bank_statements': 'documentListType.bankStatement',
    'liasse_fiscale': 'documentListType.liasseFiscale',
    'amortised_loan_schedule': 'documentListType.amortisedLoanSchedule',
    'accounting': 'documentListType.accounting',
    'invoice': 'documentListType.invoice',
    'receipt': 'documentListType.receipt',
    'kbis': 'documentListType.kbis',
    'rib': 'documentListType.rib',
    'livret_famille': 'documentListType.livretFamille',
    'payslip': 'documentListType.payslip',
    'carte_grise': 'documentListType.carteGrise',
    'proof_of_address': 'documentListType.proofAddress',
    'identity_document': 'documentListType.identityDocument',
    'driver_license': 'documentListType.drivingLicense',
    'tax': 'documentListType.tax',
    'financial_statements': 'documentListType.financial_statements',
    'certificate_of_incorporation': 'documentListType.certificate_of_incorporation',
    'proof_of_source_funds': 'documentListType.proof_of_source_funds',
    'crime_record_extract': 'documentListType.crime_record_extract',
    'social_security_card': 'documentListType.social_security_card',
    'organizational_chart': 'documentListType.organizational_chart',
    'risks_policies': 'documentListType.risks_policies',
    'lcb_ft_lab_aml_policies': 'documentListType.lcb_ft_lab_aml_policies',
    'passport': 'documentListType.passport',
    'certificate_of_good_standing': 'documentListType.certificate_of_good_standing',
  };

  /// Enrich a custom document with properties_validators and standard doc info.
  /// Returns a new map with merged fields (like React's enrichedCustomDocuments).
  static Map<String, dynamic> enrichCustomDoc(
    Map<String, dynamic> doc,
    List<dynamic> propertiesValidators,
  ) {
    final key = doc['key'] as String? ?? '';
    // 1. Try properties_validators (by key match)
    Map<String, dynamic>? validatorExtra;
    for (final v in propertiesValidators) {
      if (v is Map<String, dynamic> && v['key'] == key) {
        validatorExtra = v;
        break;
      }
    }
    // 2. Try standard doc list (by value match → get labelKey)
    final standardLabelKey = standardDocLabelKeys[key];

    final enriched = <String, dynamic>{
      if (standardLabelKey != null) 'labelKey': standardLabelKey,
      ...doc,
      if (validatorExtra != null) ...validatorExtra,
    };
    return enriched;
  }

  // -----------------------------------------------------------------------
  //  Translation data
  // -----------------------------------------------------------------------

  static const Map<String, Map<String, dynamic>> _data = {
    'fr': _fr,
    'en': _en,
    'es': _es,
    'ar': _ar,
    'it': _it,
    'pt': _pt,
    'de': _de,
    'nl': _nl,
  };

  // ========================== FRENCH ==========================
  static const _fr = <String, dynamic>{
    'intro': {
      'preambule':
          '{{appName}} utilise la plateforme Dataleon sécurisée pour automatiser la vérification des pièces d\'identité en ',
      'preambleTitle': 'Préambule',
      'languagePlaceholder': 'Sélectionner la langue',
      'requirements': {
        'title':
            'Pour poursuivre la vérification, veuillez préparer les informations suivantes :',
        'idDocument': 'Votre document d\'identité',
        'rearCamera': 'Caméra arrière pour prendre en photo votre document',
        'frontCamera': 'Caméra frontale pour prendre une photo',
      },
      'dataSecurity':
          'Vos documents sont chiffrés et seront supprimés de notre système après le traitement.',
      'termsNotice':
          'En continuant, j\'accepte les ',
      'termsOfUse': 'conditions générales d\'utilisation',
      'and': ' et la ',
      'privacyPolicy': 'politique de confidentialité',
      'startVerification': 'Démarrer ma vérification',
      'formAvailability':
          'Ce formulaire est individualisé et disponible pendant 14 jours.',
    },
    'cameraAccess': {
      'title': 'Autorisez l\'accès à votre appareil photo',
      'description':
          'Pour vérifier votre document d\'identité, nous avons besoin de pouvoir filmer à la fois votre document et votre visage. Pour ce faire, vous devez autoriser l\'accès à la caméra.',
      'privacy': 'Votre appareil photo ne sera pas utilisé en arrière-plan.',
      'allowAccess': 'J\'autorise l\'accès',
      'continue': 'Continuer',
    },
    'documentTypeStep': {
      'title': 'Sélectionnez le type de document à transmettre',
      'description':
          'Afin de nous assurer de la validité de votre document, nous avons besoin de connaître le type de document d\'identité à analyser.',
      'documents': {
        'id': 'Carte d\'identité',
        'permis': 'Permis de conduire',
        'por': 'Titre de séjour',
        'passport': 'Passeport',
        'selfie': 'Photo du visage',
      },
    },
    'documentListType': {
      'bankStatement': 'Relevé bancaire',
      'liasseFiscale': 'Liasses fiscales',
      'amortisedLoanSchedule': 'Prêt d\'amortissement',
      'accounting': 'Document Comptabilité',
      'invoice': 'Facture',
      'receipt': 'Ticket de caisse',
      'kbis': 'Extrait de KBIS',
      'rib': 'RIB',
      'livretFamille': 'Livret de famille',
      'payslip': 'Bulletin de salaire',
      'carteGrise': 'Carte grise',
      'proofAddress': 'Titre de séjour',
      'identityDocument': 'Document d\'identité',
      'drivingLicense': 'Permis de conduire',
      'tax': 'Avis d\'imposition',
      'certificate_of_incorporation': 'Certificat d\'incorporation',
      'nui_entreprise': 'NUI Entreprise',
      'financial_statements': 'États financiers',
      'RCCM': 'Registre du Commerce et du Crédit Mobilier (RCCM)',
      'proof_of_source_funds': 'Justificatif de provenance des fonds',
      'rbe': 'Registre des bénéficiaires effectifs (RBE)',
      'company_statuts': 'Statuts de la société',
      'crime_record_extract': 'Extrait de casier judiciaire',
      'social_security_card': 'Carte de sécurité sociale',
      'organizational_chart': 'Organigramme',
      'risks_policies': 'Politiques de risques',
      'lcb_ft_lab_aml_policies': 'Politiques LCB-FT / LAB-AML',
      'passport': 'Passeport',
      'certificate_of_good_standing': 'Certificat de bonne conduite',
    },
    'documentCountry': {
      'title': 'Sélectionnez le pays d\'origine de votre document',
      'description':
          'Afin de nous assurer de la validité de votre document, nous avons besoin de connaître le pays d\'origine de votre document d\'identité.',
      'searchPlaceholder': 'Rechercher un pays...',
      'noResults': 'Aucun résultat trouvé',
    },
    'cameraCapture': {
      'passportLabel': 'Photographiez votre passeport',
      'frontLabel': 'Placez le recto de votre {{document}} dans le cadre',
      'backLabel': 'Placez le verso de votre {{document}} dans le cadre',
      'selfieLabel': 'Prenez un selfie',
      'frontShort': 'Recto',
      'backShort': 'Verso',
      'selfieShort': 'Selfie',
      'docName_id': 'carte d\'identité',
      'docName_permis': 'permis de conduire',
      'docName_passport': 'passeport',
      'docName_por': 'titre de séjour',
      'analyzing': 'Analyse en cours…',
      'networkError': 'Erreur réseau, nouvelle tentative…',
      'retake': 'Reprendre',
      'confirm': 'Confirmer',
      'pleaseWait': 'Sauvegarde des données en cours',
      'validationSuccess': 'Vérifications réussies',
      'documentSaved': 'Document enregistré',
      'dataPreparation': 'Préparation des données',
      'sendingDocument': 'Envoi du document',
      'savingDocument': 'Enregistrement du document',
    },
    'cameraStatus': {
      'lightEnough': 'Il y a suffisamment de lumière',
      'eyesVisible': 'Vos yeux sont visibles',
      'faceVisible': 'Votre visage est entièrement visible',
      'text': 'La totalité du texte est lisible',
      'cardOcclusion': 'Rien ne couvre le document et le visage',
      'corners': 'Tous les coins du document sont visibles',
    },
    'validations': {
      'personalData': 'Vérification des informations personnelles',
      'personalDataError':
          'Nous n\'avons pas pu confirmer la correspondance entre votre nom '
          'et celui figurant sur votre document d\'identité. '
          'Veuillez réessayer en vous assurant que vous êtes bien '
          'le propriétaire légitime du document.',
      'blacklist': 'Vérification de conformité',
      'blacklistError': 'Le contrôle de conformité a échoué.',
      'faceSimilarity': 'Comparaison document/visage',
      'faceSimilarityError':
          'La comparaison entre le document et le visage a échoué.',
      'facialClassification': 'Classification faciale',
      'facialClassificationError': 'La classification faciale a échoué.',
    },
    'outroStep': {
      'title': 'Merci !',
      'description':
          'Vos documents ont bien été envoyés et sont en cours de vérification. '
          'Vous pouvez fermer cette page en toute sécurité.',
      'submitting': 'Nous finalisons la transmission de vos documents...',
      'redirect': 'Redirection automatique dans {{seconds}} s.',
      'retry': 'Réessayer',
      'close': 'Fermer',
    },
    'common': {
      'continue': 'Continuer',
      'language': 'Langue',
      'alreadyProcessedTitle': 'Vérification terminée',
      'alreadyProcessedDesc': 'Vous pouvez fermer cette page en toute sécurité.',
      'errorTitle': 'Une erreur est survenue',
      'errorDesc': 'Un problème est survenu lors du traitement de votre demande. Veuillez vérifier votre connexion et réessayer plus tard.',
      'retry': 'Réessayer',
      'close': 'Fermer',
    },
  };

  // ========================== ENGLISH ==========================
  static const _en = <String, dynamic>{
    'intro': {
      'preambule':
          '{{appName}} uses the secure Dataleon platform to automate identity document verification in ',
      'preambleTitle': 'Preamble',
      'languagePlaceholder': 'Select language',
      'requirements': {
        'title':
            'To continue the verification, please prepare the following information:',
        'idDocument': 'Your identity document',
        'rearCamera': 'Rear camera to take a photo of your document',
        'frontCamera': 'Front camera to take a photo',
      },
      'dataSecurity':
          'Your documents are encrypted and will be deleted from our system after processing.',
      'termsNotice': 'By continuing, I accept the ',
      'termsOfUse': 'terms of use',
      'and': ' and the ',
      'privacyPolicy': 'privacy policy',
      'startVerification': 'Start my verification',
      'formAvailability':
          'This form is personalized and available for 14 days.',
    },
    'cameraAccess': {
      'title': 'Allow access to your camera',
      'description':
          'To verify your identity document, we need to be able to film both your document and your face. To do this, you must allow access to the camera.',
      'privacy': 'Your camera will not be used in the background.',
      'allowAccess': 'I allow access',
      'continue': 'Continue',
    },
    'documentTypeStep': {
      'title': 'Select the type of document to submit',
      'description':
          'To ensure the validity of your document, we need to know the type of identity document to analyze.',
      'documents': {
        'id': 'Identity Card',
        'permis': 'Driving License',
        'por': 'Residence Permit',
        'passport': 'Passport',
        'selfie': 'Selfie',
      },
    },
    'documentListType': {
      'bankStatement': 'Bank Statement',
      'liasseFiscale': 'Liasse Fiscale',
      'amortisedLoanSchedule': 'Amortised Loan Schedule',
      'accounting': 'Accounting document',
      'invoice': 'Invoice',
      'receipt': 'Receipt',
      'kbis': 'KBIS',
      'rib': 'RIB',
      'livretFamille': 'Family Booklet',
      'payslip': 'Payslip',
      'carteGrise': 'Gray card',
      'proofAddress': 'Residence Permit',
      'identityDocument': 'Identity Document',
      'drivingLicense': 'Driving License',
      'tax': 'Tax Document',
      'certificate_of_incorporation': 'Certificate of incorporation',
      'nui_entreprise': 'Company NUI',
      'financial_statements': 'Financial statements',
      'RCCM': 'Trade and movable credit register (RCCM)',
      'proof_of_source_funds': 'Proof of source of funds',
      'rbe': 'Register of Beneficial Owners (RBE)',
      'company_statuts': 'Company statutes',
      'crime_record_extract': 'Crime record extract',
      'social_security_card': 'Social security card',
      'organizational_chart': 'Organizational chart',
      'risks_policies': 'Risks policies',
      'lcb_ft_lab_aml_policies': 'LCB-FT / LAB-AML policies',
      'passport': 'Passport',
      'certificate_of_good_standing': 'Certificate of good standing',
    },
    'documentCountry': {
      'title': 'Select the country of origin of your document',
      'description':
          'To ensure the validity of your document, we need to know the country of origin of your identity document.',
      'searchPlaceholder': 'Search for a country...',
      'noResults': 'No results found',
    },
    'cameraCapture': {
      'passportLabel': 'Photograph your passport',
      'frontLabel': 'Place the front of your {{document}} in the frame',
      'backLabel': 'Place the back of your {{document}} in the frame',
      'selfieLabel': 'Take a selfie',
      'frontShort': 'Front',
      'backShort': 'Back',
      'selfieShort': 'Selfie',
      'docName_id': 'ID card',
      'docName_permis': 'driver\'s license',
      'docName_passport': 'passport',
      'docName_por': 'residence permit',
      'analyzing': 'Analyzing…',
      'networkError': 'Network error, retrying…',
      'retake': 'Retake',
      'confirm': 'Confirm',
      'pleaseWait': 'Saving data in progress',
      'validationSuccess': 'Verifications passed',
      'documentSaved': 'Document saved',
      'dataPreparation': 'Preparing data',
      'sendingDocument': 'Sending document',
      'savingDocument': 'Saving document',
    },
    'cameraStatus': {
      'lightEnough': 'There is sufficient lighting',
      'eyesVisible': 'Your eyes are clearly visible',
      'faceVisible': 'Your entire face is fully visible',
      'text': 'All text is readable',
      'cardOcclusion': 'Nothing is covering the document and face',
      'corners': 'All corners of the document are visible',
    },
    'validations': {
      'personalData': 'Verifying personal information',
      'personalDataError':
          'We couldn\'t verify the match between your name and the one on your '
          'identity document. Please try again, ensuring you are the legitimate '
          'owner of the document.',
      'blacklist': 'Compliance check',
      'blacklistError': 'Compliance check failed.',
      'faceSimilarity': 'Face matching',
      'faceSimilarityError': 'Face matching failed.',
      'facialClassification': 'Facial classification',
      'facialClassificationError': 'Facial classification failed.',
    },
    'outroStep': {
      'title': 'Thank you!',
      'description':
          'Your documents have been sent and are being verified. '
          'You can safely close this page.',
      'submitting': 'We are finalizing the transmission of your documents...',
      'redirect': 'Automatic redirect in {{seconds}} s.',
      'retry': 'Retry',
      'close': 'Close',
    },
    'common': {
      'continue': 'Continue',
      'language': 'Language',
      'alreadyProcessedTitle': 'Verification complete',
      'alreadyProcessedDesc': 'You can safely close this page.',
      'errorTitle': 'An error occurred',
      'errorDesc': 'A problem occurred while processing your request. Please check your connection and try again later.',
      'retry': 'Retry',
      'close': 'Close',
    },
  };

  // ========================== SPANISH ==========================
  static const _es = <String, dynamic>{
    'intro': {
      'preambule':
          '{{appName}} utiliza la plataforma segura Dataleon para automatizar la verificación de documentos de identidad en ',
      'preambleTitle': 'Preámbulo',
      'languagePlaceholder': 'Seleccionar idioma',
      'requirements': {
        'title':
            'Para continuar la verificación, prepare la siguiente información:',
        'idDocument': 'Su documento de identidad',
        'rearCamera': 'Cámara trasera para fotografiar su documento',
        'frontCamera': 'Cámara frontal para tomar una foto',
      },
      'dataSecurity':
          'Sus documentos están cifrados y se eliminarán de nuestro sistema después del procesamiento.',
      'termsNotice': 'Al continuar, acepto los ',
      'termsOfUse': 'términos de uso',
      'and': ' y la ',
      'privacyPolicy': 'política de privacidad',
      'startVerification': 'Iniciar mi verificación',
    },
    'cameraAccess': {
      'title': 'Permita el acceso a su cámara',
      'description':
          'Para verificar su documento de identidad, necesitamos poder filmar su documento y su rostro. Para ello, debe permitir el acceso a la cámara.',
      'privacy': 'Su cámara no se utilizará en segundo plano.',
      'allowAccess': 'Permitir acceso',
      'continue': 'Continuar',
    },
    'documentTypeStep': {
      'title': 'Seleccione el tipo de documento a enviar',
      'description':
          'Para asegurar la validez de su documento, necesitamos conocer el tipo de documento de identidad a analizar.',
      'documents': {
        'id': 'Documento de identidad',
        'permis': 'Licencia de conducir',
        'por': 'Permiso de residencia',
        'passport': 'Pasaporte',
        'selfie': 'Selfie',
      },
    },
    'documentCountry': {
      'title': 'Seleccione el país de origen de su documento',
      'description':
          'Para asegurar la validez de su documento, necesitamos conocer el país de origen de su documento de identidad.',
      'searchPlaceholder': 'Buscar un país...',
      'noResults': 'No se encontraron resultados',
    },
    'cameraCapture': {
      'passportLabel': 'Fotografíe su pasaporte',
      'frontLabel': 'Coloque el frente de su {{document}} en el marco',
      'backLabel': 'Coloque el reverso de su {{document}} en el marco',
      'selfieLabel': 'Tome un selfie',
      'frontShort': 'Frente',
      'backShort': 'Reverso',
      'selfieShort': 'Selfie',
      'docName_id': 'documento de identidad',
      'docName_permis': 'licencia de conducir',
      'docName_passport': 'pasaporte',
      'docName_por': 'permiso de residencia',
      'analyzing': 'Analizando…',
      'retake': 'Repetir',
      'confirm': 'Confirmar',
      'validationSuccess': 'Verificaciones exitosas',
      'documentSaved': 'Documento guardado',
      'dataPreparation': 'Preparando datos',
      'sendingDocument': 'Enviando documento',
      'savingDocument': 'Guardando documento',
    },
    'cameraStatus': {
      'lightEnough': 'Hay suficiente iluminación',
      'eyesVisible': 'Sus ojos son claramente visibles',
      'faceVisible': 'Su rostro completo es visible',
      'text': 'Todo el texto es legible',
      'cardOcclusion': 'Nada cubre el documento ni el rostro',
      'corners': 'Todas las esquinas del documento son visibles',
    },
    'validations': {
      'personalData': 'Verificación de información personal',
      'personalDataError':
          'No pudimos verificar la correspondencia entre su nombre y el de su documento.',
      'blacklist': 'Verificación de cumplimiento',
      'blacklistError': 'Falló la verificación de cumplimiento.',
      'faceSimilarity': 'Comparación de rostros',
      'faceSimilarityError': 'Falló la comparación de rostros.',
      'facialClassification': 'Clasificación facial',
      'facialClassificationError': 'Falló la clasificación facial.',
    },
    'outroStep': {
      'title': '¡Gracias!',
      'description':
          'Sus documentos han sido enviados y están siendo verificados. '
          'Puede cerrar esta página de forma segura.',
      'submitting': 'Estamos finalizando la transmisión de sus documentos...',
      'redirect': 'Redirección automática en {{seconds}} s.',
      'retry': 'Reintentar',
      'close': 'Cerrar',
    },
    'common': {
      'continue': 'Continuar',
      'language': 'Idioma',
    },
  };

  // ========================== ARABIC ==========================
  static const _ar = <String, dynamic>{
    'intro': {
      'preambule':
          '{{appName}} يستخدم منصة Dataleon الآمنة لأتمتة التحقق من وثائق الهوية في ',
      'preambleTitle': 'مقدمة',
      'languagePlaceholder': 'اختر اللغة',
      'requirements': {
        'title': 'لمتابعة التحقق، يرجى تحضير المعلومات التالية:',
        'idDocument': 'وثيقة هويتك',
        'rearCamera': 'الكاميرا الخلفية لتصوير وثيقتك',
        'frontCamera': 'الكاميرا الأمامية لالتقاط صورة',
      },
      'dataSecurity': 'وثائقك مشفرة وسيتم حذفها من نظامنا بعد المعالجة.',
      'termsNotice': 'بالمتابعة، أوافق على ',
      'termsOfUse': 'شروط الاستخدام',
      'and': ' و',
      'privacyPolicy': 'سياسة الخصوصية',
      'startVerification': 'بدء التحقق',
    },
    'cameraAccess': {
      'title': 'اسمح بالوصول إلى الكاميرا',
      'description':
          'للتحقق من وثيقة هويتك، نحتاج إلى تصوير وثيقتك ووجهك. للقيام بذلك، يجب أن تسمح بالوصول إلى الكاميرا.',
      'privacy': 'لن يتم استخدام الكاميرا في الخلفية.',
      'allowAccess': 'أسمح بالوصول',
      'continue': 'متابعة',
    },
    'documentTypeStep': {
      'title': 'اختر نوع الوثيقة المراد إرسالها',
      'description': 'لضمان صلاحية وثيقتك، نحتاج لمعرفة نوع وثيقة الهوية.',
      'documents': {
        'id': 'بطاقة الهوية',
        'permis': 'رخصة القيادة',
        'por': 'تصريح الإقامة',
        'passport': 'جواز السفر',
        'selfie': 'صورة ذاتية',
      },
    },
    'documentCountry': {
      'title': 'اختر بلد إصدار وثيقتك',
      'description': 'لضمان صلاحية وثيقتك، نحتاج لمعرفة بلد إصدار وثيقة هويتك.',
      'searchPlaceholder': 'البحث عن بلد...',
      'noResults': 'لم يتم العثور على نتائج',
    },
    'cameraCapture': {
      'passportLabel': 'صوّر جواز سفرك',
      'frontLabel': 'ضع الوجه الأمامي لـ {{document}} في الإطار',
      'backLabel': 'ضع الوجه الخلفي لـ {{document}} في الإطار',
      'selfieLabel': 'التقط صورة ذاتية',
      'analyzing': 'جاري التحليل…',
      'retake': 'إعادة الالتقاط',
      'confirm': 'تأكيد',
      'validationSuccess': 'تم التحقق بنجاح',
      'documentSaved': 'تم حفظ الوثيقة',
    },
    'cameraStatus': {
      'lightEnough': 'الإضاءة كافية',
      'eyesVisible': 'عيناك مرئيتان بوضوح',
      'faceVisible': 'وجهك مرئي بالكامل',
      'text': 'كل النص مقروء',
      'cardOcclusion': 'لا شيء يغطي الوثيقة أو الوجه',
      'corners': 'جميع زوايا الوثيقة مرئية',
    },
    'outroStep': {
      'title': 'شكراً!',
      'description': 'تم إرسال وثائقك وهي قيد التحقق. يمكنك إغلاق هذه الصفحة بأمان.',
      'submitting': 'نقوم بإنهاء إرسال وثائقك...',
      'retry': 'إعادة المحاولة',
      'close': 'إغلاق',
    },
    'common': {
      'continue': 'متابعة',
      'language': 'اللغة',
    },
  };

  // ========================== ITALIAN ==========================
  static const _it = <String, dynamic>{
    'intro': {
      'preambule':
          '{{appName}} utilizza la piattaforma sicura Dataleon per automatizzare la verifica dei documenti d\'identità in ',
      'preambleTitle': 'Preambolo',
      'languagePlaceholder': 'Seleziona la lingua',
      'requirements': {
        'title':
            'Per continuare la verifica, prepara le seguenti informazioni:',
        'idDocument': 'Il tuo documento d\'identità',
        'rearCamera': 'Fotocamera posteriore per fotografare il documento',
        'frontCamera': 'Fotocamera frontale per scattare una foto',
      },
      'dataSecurity':
          'I tuoi documenti sono criptati e verranno eliminati dal nostro sistema dopo l\'elaborazione.',
      'termsNotice': 'Continuando, accetto i ',
      'termsOfUse': 'termini di utilizzo',
      'and': ' e la ',
      'privacyPolicy': 'informativa sulla privacy',
      'startVerification': 'Avvia la mia verifica',
    },
    'cameraAccess': {
      'title': 'Consenti l\'accesso alla fotocamera',
      'description':
          'Per verificare il tuo documento d\'identità, dobbiamo poter filmare sia il documento che il tuo viso. Per farlo, devi consentire l\'accesso alla fotocamera.',
      'privacy': 'La fotocamera non verrà utilizzata in background.',
      'allowAccess': 'Consento l\'accesso',
      'continue': 'Continua',
    },
    'documentTypeStep': {
      'title': 'Seleziona il tipo di documento da inviare',
      'description':
          'Per garantire la validità del documento, dobbiamo conoscere il tipo di documento d\'identità da analizzare.',
      'documents': {
        'id': 'Carta d\'identità',
        'permis': 'Patente di guida',
        'por': 'Permesso di soggiorno',
        'passport': 'Passaporto',
        'selfie': 'Selfie',
      },
    },
    'documentCountry': {
      'title': 'Seleziona il paese di origine del tuo documento',
      'description':
          'Per garantire la validità del documento, dobbiamo conoscere il paese di origine del tuo documento d\'identità.',
      'searchPlaceholder': 'Cerca un paese...',
      'noResults': 'Nessun risultato trovato',
    },
    'cameraCapture': {
      'passportLabel': 'Fotografa il tuo passaporto',
      'frontLabel': 'Posiziona il fronte del tuo {{document}} nel riquadro',
      'backLabel': 'Posiziona il retro del tuo {{document}} nel riquadro',
      'selfieLabel': 'Scatta un selfie',
      'analyzing': 'Analisi in corso…',
      'retake': 'Riprendi',
      'confirm': 'Conferma',
      'validationSuccess': 'Verifiche superate',
      'documentSaved': 'Documento salvato',
    },
    'cameraStatus': {
      'lightEnough': 'C\'è sufficiente illuminazione',
      'eyesVisible': 'I tuoi occhi sono chiaramente visibili',
      'faceVisible': 'Il tuo viso è completamente visibile',
      'text': 'Tutto il testo è leggibile',
      'cardOcclusion': 'Nulla copre il documento e il viso',
      'corners': 'Tutti gli angoli del documento sono visibili',
    },
    'outroStep': {
      'title': 'Grazie!',
      'description':
          'I tuoi documenti sono stati inviati e sono in fase di verifica. Puoi chiudere questa pagina in sicurezza.',
      'submitting': 'Stiamo finalizzando la trasmissione dei tuoi documenti...',
      'retry': 'Riprova',
      'close': 'Chiudi',
    },
    'common': {
      'continue': 'Continua',
      'language': 'Lingua',
    },
  };

  // ========================== PORTUGUESE ==========================
  static const _pt = <String, dynamic>{
    'intro': {
      'preambule':
          '{{appName}} utiliza a plataforma segura Dataleon para automatizar a verificação de documentos de identidade em ',
      'preambleTitle': 'Preâmbulo',
      'languagePlaceholder': 'Selecionar idioma',
      'requirements': {
        'title':
            'Para continuar a verificação, prepare as seguintes informações:',
        'idDocument': 'Seu documento de identidade',
        'rearCamera': 'Câmera traseira para fotografar seu documento',
        'frontCamera': 'Câmera frontal para tirar uma foto',
      },
      'dataSecurity':
          'Seus documentos são criptografados e serão excluídos do nosso sistema após o processamento.',
      'termsNotice': 'Ao continuar, aceito os ',
      'termsOfUse': 'termos de uso',
      'and': ' e a ',
      'privacyPolicy': 'política de privacidade',
      'startVerification': 'Iniciar minha verificação',
    },
    'cameraAccess': {
      'title': 'Permita o acesso à sua câmera',
      'description':
          'Para verificar seu documento de identidade, precisamos filmar seu documento e seu rosto. Para isso, você deve permitir o acesso à câmera.',
      'privacy': 'Sua câmera não será usada em segundo plano.',
      'allowAccess': 'Eu permito o acesso',
      'continue': 'Continuar',
    },
    'documentTypeStep': {
      'title': 'Selecione o tipo de documento a enviar',
      'description':
          'Para garantir a validade do documento, precisamos saber o tipo de documento de identidade a analisar.',
      'documents': {
        'id': 'Carteira de identidade',
        'permis': 'Carteira de motorista',
        'por': 'Autorização de residência',
        'passport': 'Passaporte',
        'selfie': 'Selfie',
      },
    },
    'documentCountry': {
      'title': 'Selecione o país de origem do seu documento',
      'description':
          'Para garantir a validade do documento, precisamos saber o país de origem do seu documento de identidade.',
      'searchPlaceholder': 'Buscar um país...',
      'noResults': 'Nenhum resultado encontrado',
    },
    'cameraCapture': {
      'passportLabel': 'Fotografe seu passaporte',
      'frontLabel': 'Coloque a frente do seu {{document}} no quadro',
      'backLabel': 'Coloque o verso do seu {{document}} no quadro',
      'selfieLabel': 'Tire uma selfie',
      'analyzing': 'Analisando…',
      'retake': 'Refazer',
      'confirm': 'Confirmar',
      'validationSuccess': 'Verificações aprovadas',
      'documentSaved': 'Documento salvo',
    },
    'cameraStatus': {
      'lightEnough': 'Há iluminação suficiente',
      'eyesVisible': 'Seus olhos estão claramente visíveis',
      'faceVisible': 'Seu rosto está totalmente visível',
      'text': 'Todo o texto está legível',
      'cardOcclusion': 'Nada cobre o documento e o rosto',
      'corners': 'Todos os cantos do documento estão visíveis',
    },
    'outroStep': {
      'title': 'Obrigado!',
      'description':
          'Seus documentos foram enviados e estão sendo verificados. Você pode fechar esta página com segurança.',
      'submitting': 'Estamos finalizando a transmissão dos seus documentos...',
      'retry': 'Tentar novamente',
      'close': 'Fechar',
    },
    'common': {
      'continue': 'Continuar',
      'language': 'Idioma',
    },
  };

  // ========================== GERMAN ==========================
  static const _de = <String, dynamic>{
    'intro': {
      'preambule':
          '{{appName}} nutzt die sichere Dataleon-Plattform zur automatisierten Überprüfung von Ausweisdokumenten in ',
      'preambleTitle': 'Präambel',
      'languagePlaceholder': 'Sprache wählen',
      'requirements': {
        'title':
            'Um die Überprüfung fortzusetzen, bereiten Sie bitte folgende Informationen vor:',
        'idDocument': 'Ihr Ausweisdokument',
        'rearCamera': 'Rückkamera zum Fotografieren Ihres Dokuments',
        'frontCamera': 'Frontkamera für ein Foto',
      },
      'dataSecurity':
          'Ihre Dokumente sind verschlüsselt und werden nach der Verarbeitung aus unserem System gelöscht.',
      'termsNotice': 'Durch Fortfahren akzeptiere ich die ',
      'termsOfUse': 'Nutzungsbedingungen',
      'and': ' und die ',
      'privacyPolicy': 'Datenschutzerklärung',
      'startVerification': 'Meine Überprüfung starten',
    },
    'cameraAccess': {
      'title': 'Erlauben Sie den Zugriff auf Ihre Kamera',
      'description':
          'Um Ihr Ausweisdokument zu überprüfen, müssen wir sowohl Ihr Dokument als auch Ihr Gesicht filmen. Dazu müssen Sie den Kamerazugriff erlauben.',
      'privacy': 'Ihre Kamera wird nicht im Hintergrund verwendet.',
      'allowAccess': 'Zugriff erlauben',
      'continue': 'Weiter',
    },
    'documentTypeStep': {
      'title': 'Wählen Sie den Dokumententyp aus',
      'description':
          'Um die Gültigkeit Ihres Dokuments sicherzustellen, müssen wir den Typ des Ausweisdokuments kennen.',
      'documents': {
        'id': 'Personalausweis',
        'permis': 'Führerschein',
        'por': 'Aufenthaltstitel',
        'passport': 'Reisepass',
        'selfie': 'Selfie',
      },
    },
    'documentCountry': {
      'title': 'Wählen Sie das Herkunftsland Ihres Dokuments',
      'description':
          'Um die Gültigkeit sicherzustellen, müssen wir das Herkunftsland Ihres Ausweisdokuments kennen.',
      'searchPlaceholder': 'Land suchen...',
      'noResults': 'Keine Ergebnisse gefunden',
    },
    'cameraCapture': {
      'passportLabel': 'Fotografieren Sie Ihren Reisepass',
      'frontLabel': 'Platzieren Sie die Vorderseite Ihres {{document}} im Rahmen',
      'backLabel': 'Platzieren Sie die Rückseite Ihres {{document}} im Rahmen',
      'selfieLabel': 'Machen Sie ein Selfie',
      'analyzing': 'Analyse läuft…',
      'retake': 'Wiederholen',
      'confirm': 'Bestätigen',
      'validationSuccess': 'Überprüfungen bestanden',
      'documentSaved': 'Dokument gespeichert',
    },
    'cameraStatus': {
      'lightEnough': 'Es gibt ausreichend Beleuchtung',
      'eyesVisible': 'Ihre Augen sind deutlich sichtbar',
      'faceVisible': 'Ihr gesamtes Gesicht ist sichtbar',
      'text': 'Der gesamte Text ist lesbar',
      'cardOcclusion': 'Nichts verdeckt das Dokument und das Gesicht',
      'corners': 'Alle Ecken des Dokuments sind sichtbar',
    },
    'outroStep': {
      'title': 'Danke!',
      'description':
          'Ihre Dokumente wurden gesendet und werden überprüft. Sie können diese Seite sicher schließen.',
      'submitting': 'Wir schließen die Übertragung Ihrer Dokumente ab...',
      'retry': 'Erneut versuchen',
      'close': 'Schließen',
    },
    'common': {
      'continue': 'Weiter',
      'language': 'Sprache',
    },
  };

  // ========================== DUTCH ==========================
  static const _nl = <String, dynamic>{
    'intro': {
      'preambule':
          '{{appName}} gebruikt het beveiligde Dataleon-platform om de verificatie van identiteitsdocumenten te automatiseren in ',
      'preambleTitle': 'Preambule',
      'languagePlaceholder': 'Taal selecteren',
      'requirements': {
        'title':
            'Om de verificatie voort te zetten, bereidt u de volgende informatie voor:',
        'idDocument': 'Uw identiteitsdocument',
        'rearCamera': 'Achterste camera om uw document te fotograferen',
        'frontCamera': 'Frontcamera om een foto te maken',
      },
      'dataSecurity':
          'Uw documenten zijn versleuteld en worden na verwerking uit ons systeem verwijderd.',
      'termsNotice': 'Door verder te gaan, accepteer ik de ',
      'termsOfUse': 'gebruiksvoorwaarden',
      'and': ' en het ',
      'privacyPolicy': 'privacybeleid',
      'startVerification': 'Mijn verificatie starten',
    },
    'cameraAccess': {
      'title': 'Geef toegang tot uw camera',
      'description':
          'Om uw identiteitsdocument te verifiëren, moeten we zowel uw document als uw gezicht kunnen filmen. Hiervoor moet u cameratoegang verlenen.',
      'privacy': 'Uw camera wordt niet op de achtergrond gebruikt.',
      'allowAccess': 'Ik geef toegang',
      'continue': 'Doorgaan',
    },
    'documentTypeStep': {
      'title': 'Selecteer het type document om in te dienen',
      'description':
          'Om de geldigheid van uw document te waarborgen, moeten we het type identiteitsdocument kennen.',
      'documents': {
        'id': 'Identiteitskaart',
        'permis': 'Rijbewijs',
        'por': 'Verblijfsvergunning',
        'passport': 'Paspoort',
        'selfie': 'Selfie',
      },
    },
    'documentCountry': {
      'title': 'Selecteer het land van herkomst van uw document',
      'description':
          'Om de geldigheid te waarborgen, moeten we het land van herkomst van uw identiteitsdocument kennen.',
      'searchPlaceholder': 'Zoek een land...',
      'noResults': 'Geen resultaten gevonden',
    },
    'cameraCapture': {
      'passportLabel': 'Fotografeer uw paspoort',
      'frontLabel':
          'Plaats de voorkant van uw {{document}} in het kader',
      'backLabel':
          'Plaats de achterkant van uw {{document}} in het kader',
      'selfieLabel': 'Neem een selfie',
      'analyzing': 'Bezig met analyseren…',
      'retake': 'Opnieuw',
      'confirm': 'Bevestigen',
      'validationSuccess': 'Verificaties geslaagd',
      'documentSaved': 'Document opgeslagen',
    },
    'cameraStatus': {
      'lightEnough': 'Er is voldoende verlichting',
      'eyesVisible': 'Uw ogen zijn duidelijk zichtbaar',
      'faceVisible': 'Uw hele gezicht is zichtbaar',
      'text': 'Alle tekst is leesbaar',
      'cardOcclusion': 'Niets bedekt het document en het gezicht',
      'corners': 'Alle hoeken van het document zijn zichtbaar',
    },
    'outroStep': {
      'title': 'Bedankt!',
      'description':
          'Uw documenten zijn verzonden en worden geverifieerd. U kunt deze pagina veilig sluiten.',
      'submitting':
          'We finaliseren de overdracht van uw documenten...',
      'retry': 'Opnieuw proberen',
      'close': 'Sluiten',
    },
    'common': {
      'continue': 'Doorgaan',
      'language': 'Taal',
    },
  };
}
