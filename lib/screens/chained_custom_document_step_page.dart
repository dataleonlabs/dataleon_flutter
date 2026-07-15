import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../flow/dataleon_flow_controller.dart';
import '../flow/dataleon_flow_step.dart';
import '../i18n/dataleon_localizations.dart';
import '../widgets/dataleon_step_header.dart';

class ChainedCustomDocumentStepPage extends StatefulWidget {
  const ChainedCustomDocumentStepPage({
    super.key,
    required this.controller,
  });

  final DataleonFlowController controller;

  @override
  State<ChainedCustomDocumentStepPage> createState() =>
      _ChainedCustomDocumentStepPageState();
}

class _ChainedCustomDocumentStepPageState
    extends State<ChainedCustomDocumentStepPage> {
  final TextEditingController _searchController = TextEditingController();
  late final TapGestureRecognizer _skipOptionalRecognizer =
      TapGestureRecognizer()..onTap = _handleSkipOptionalDocument;
  Timer? _loadingDotsTimer;
  Timer? _progressAnimationTimer;
  PlatformFile? _selectedFile;
  bool _showOptionPicker = true;
  bool _isUploading = false;
  double _uploadProgress = 0;
  double _displayProgress = 0;
  String? _uploadError;
  String _loadingDots = '';
  _ChainedDocumentMode _activeMode = _ChainedDocumentMode.upload;
  late final String _sessionId;

  DataleonFlowController get controller => widget.controller;

  String get _lang => controller.languageCode;
  String _t(String key, {String? fallback}) =>
      DataleonLocalizations.t(_lang, key, fallback: fallback);

  Map<String, dynamic> get _document =>
      controller.activeChainedDocument ??
      controller.selectedCustomDocument ??
      const <String, dynamic>{};

  List<Map<String, dynamic>> get _options {
    final source = _document['proposedOptions'];
    if (source is! List) {
      return const <Map<String, dynamic>>[];
    }

    final items = source
        .whereType<Map>()
        .map((option) => Map<String, dynamic>.from(option))
        .toList(growable: true);
    items.sort((left, right) {
      final leftOrder = (left['order'] as num?)?.toInt() ?? 0;
      final rightOrder = (right['order'] as num?)?.toInt() ?? 0;
      return leftOrder.compareTo(rightOrder);
    });
    return items;
  }

  bool get _uniformColor =>
      controller.advancedDesignConfiguration['uniformPrincipalColor'] == true;
  Color get _accentColor => Color(_parseHexColor(
        controller.dashboardConfiguration['buttonColor'] as String?,
        'FF111827',
      ));

  bool get _hasProposedOptions => _options.isNotEmpty;
  bool get _isOptionalDocument => _document['required'] == false;
  bool get _uploadEnabled => _document['uploadEnabled'] == true;
  bool get _uploadOnlyMode => _document['uploadOnlyMode'] == true;
  bool get _canUseUpload => _uploadOnlyMode || _uploadEnabled;
  bool get _canUseCamera => !_uploadOnlyMode;
  bool get _isSelectionResolved =>
      !_hasProposedOptions || controller.selectedChainedDocumentOption != null;
  bool get _shouldShowUpload =>
      _canUseUpload && _isSelectionResolved && !_showOptionPicker;

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    _syncWithCurrentDocument();
  }

  @override
  void didUpdateWidget(covariant ChainedCustomDocumentStepPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.activeChainedDocument?['key'] !=
            controller.activeChainedDocument?['key'] ||
        oldWidget.controller.selectedChainedDocumentOption?['id'] !=
            controller.selectedChainedDocumentOption?['id']) {
      _syncWithCurrentDocument();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _skipOptionalRecognizer.dispose();
    _loadingDotsTimer?.cancel();
    _progressAnimationTimer?.cancel();
    super.dispose();
  }

  void _syncWithCurrentDocument() {
    _showOptionPicker =
        _hasProposedOptions && controller.selectedChainedDocumentOption == null;
    _selectedFile = null;
    _activeMode = _canUseUpload
        ? _ChainedDocumentMode.upload
        : _ChainedDocumentMode.camera;
    _isUploading = false;
    _uploadProgress = 0;
    _displayProgress = 0;
    _uploadError = null;
    _loadingDots = '';
    _searchController.clear();
  }

  void _handleHeaderBack() {
    if (!_showOptionPicker) {
      setState(() {
        _searchController.clear();
        _showOptionPicker = true;
      });
      return;
    }

    controller.exitChainedDocumentFlow();
  }

  void _startLoadingDots() {
    _loadingDotsTimer?.cancel();
    _loadingDotsTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (!mounted || !_isUploading) {
        return;
      }
      setState(() {
        _loadingDots = _loadingDots.length >= 3 ? '' : '$_loadingDots.';
      });
    });
  }

  void _startProgressAnimation() {
    _progressAnimationTimer?.cancel();
    _progressAnimationTimer =
        Timer.periodic(const Duration(milliseconds: 24), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final gap = _uploadProgress - _displayProgress;
      if (gap.abs() < 1) {
        setState(() {
          _displayProgress = _uploadProgress;
        });
        if (!_isUploading) {
          timer.cancel();
        }
        return;
      }

      setState(() {
        _displayProgress += gap * 0.18;
      });
    });
  }

  Future<void> _handlePickFile() async {
    if (_isUploading) {
      return;
    }

    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );

    final file =
        result != null && result.files.isNotEmpty ? result.files.first : null;
    if (file == null || file.bytes == null) {
      return;
    }

    setState(() {
      _uploadError = null;
      _selectedFile = file;
    });

    await _handleUpload(file);
  }

  Future<void> _handleUpload(PlatformFile file) async {
    if ((_hasProposedOptions && !_isSelectionResolved) || _isUploading) {
      return;
    }

    final bytes = file.bytes;
    if (bytes == null) {
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadError = null;
      _uploadProgress = 8;
      _displayProgress = 8;
    });
    _startLoadingDots();
    _startProgressAnimation();

    try {
      final extension = (file.extension ?? 'jpg').toLowerCase();
      final filename =
          '${DateTime.now().millisecondsSinceEpoch}-custom-upload.$extension';
      final contentType = _contentTypeForExtension(extension);

      final signed = await controller.apiService.generateSignedUploadUrl(
        objectName: filename,
        contentType: contentType,
      );

      setState(() {
        _uploadProgress = 60;
      });

      final signedUrl = signed['signedUrl'] as String? ?? '';
      if (signedUrl.isEmpty) {
        throw StateError('URL signée introuvable.');
      }

      final publicUrl = await controller.apiService.uploadBytesToSignedUrl(
        signedUrl: signedUrl,
        bytes: bytes,
        contentType: contentType,
      );

      setState(() {
        _uploadProgress = 92;
      });

      // Chained documents are saved only through the other-documents
      // verification endpoint. save-document is reserved for standard
      // ("vertical") documents and must not be called here.
      //
      // This mirrors the web flow: other-documents receives the same rich
      // verification payload and headers as save-document, plus the
      // chained-specific fields. To match the backend contract exactly:
      //   document_type    -> activeChainedDocument.key
      //   document_subtype -> documentType (the selected option internalName)
      //   language         -> current language
      final otherPayload = _buildUploadPayload(
        fileUrl: publicUrl,
        filename: filename,
      )
        ..['document_type'] = controller.activeChainedDocument?['key'] ?? ''
        ..['document_subtype'] = controller.documentType ?? ''
        ..['language'] = controller.languageCode;

      final otherResp = await controller.apiService.applyRequestService(
        path:
            '/individuals/${controller.config.sessionId}/verifications/other-documents',
        data: otherPayload,
        headers: _requestHeaders(),
      );

      // Parse business validation results if present: checks, validations or errors
      List<dynamic>? validations;
      if (otherResp['checks'] is List) {
        validations = otherResp['checks'] as List<dynamic>;
      } else if (otherResp['validations'] is List) {
        validations = otherResp['validations'] as List<dynamic>;
      } else if (otherResp['errors'] is List) {
        validations = otherResp['errors'] as List<dynamic>;
      }

      if (validations != null && validations.isNotEmpty) {
        for (final item in validations) {
          if (item is Map && item['validate'] == false) {
            final msg = (item['message'] as String?) ?? (item['label'] as String?) ?? '';
            if (msg.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _uploadError = msg;
                  _selectedFile = null;
                  _uploadProgress = 0;
                  _displayProgress = 0;
                });
              }
              return;
            }
          }
        }
      }

      final key = (signed['key'] as String?) ?? filename;
      controller.saveUploadedFile(
        phase: 'front',
        url: publicUrl,
        name: filename,
        key: key,
      );

      setState(() {
        _uploadProgress = 100;
      });

      final selectedOptionId = controller.selectedChainedDocumentOption?['id']?.toString();
      final startedChainedDocument = controller.completeCurrentDocumentAndContinue(
        completedSelectedOptionId: selectedOptionId,
      );
      if (!startedChainedDocument) {
        controller.goToStep(DataleonFlowStep.success);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final baseMessage = _lang.startsWith('fr')
          ? 'Le document n\'a pas pu etre televerse. Veuillez reessayer.'
          : 'The document could not be uploaded. Please try again.';
      setState(() {
        _uploadError = '$baseMessage\n($error)';
        _selectedFile = null;
        _uploadProgress = 0;
        _displayProgress = 0;
      });
    } finally {
      _loadingDotsTimer?.cancel();
      if (mounted) {
        setState(() {
          _isUploading = false;
          _loadingDots = '';
        });
      }
    }
  }

  Map<String, dynamic> _buildUploadPayload({
    required String fileUrl,
    required String filename,
  }) {
    final request = controller.requestResult;
    final document = _document;
    final isCardDocument = document['isCardDocument'] == true ||
        (document['doc'] is Map &&
            (document['doc'] as Map)['isCardDocument'] == true);
    final payload = <String, dynamic>{
      'url': '$fileUrl?filename=$filename',
      'disable_auto_save_doc': 'true',
      'step': 'step-1',
      'page_face': 'recto',
      'document_face': 'recto',
      'filename': filename,
      'form_document_type': controller.documentType ?? '',
      'form_document_country': controller.documentCountry ?? '',
      'session_id': _sessionId,
      'enable_card_detect': isCardDocument.toString(),
      'save_only_response': 'true',
      'request_type': 'webview',
    };

    final requestId = request['id'];
    if (requestId != null) {
      payload['task_id'] = '$requestId';
      payload['request_follow_id'] = '$requestId';
    }

    _parseRequestApiForm().forEach((key, value) {
      if (key == 'callback_url') {
        payload['callback_url_rt'] = value;
      } else {
        payload[key] = value;
      }
    });
    payload.remove('callback_url');
    return payload;
  }

  Map<String, String> _requestHeaders() {
    return <String, String>{
      'X-Session-ID': _sessionId,
      'X-Custom-Document': 'true',
    };
  }

  Map<String, dynamic> _parseRequestApiForm() {
    final raw = controller.requestResult['requestAPI'];
    if (raw is! String || raw.isEmpty) {
      return const <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final form = decoded['form'];
      if (form is Map<String, dynamic>) {
        return form;
      }
    } catch (_) {
      return const <String, dynamic>{};
    }

    return const <String, dynamic>{};
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  String _documentName(Map<String, dynamic> document) {
    final validatorMeta =
        (controller.requestConfig?['properties_validators'] as List?)
                ?.whereType<Map>()
                .cast<Map<dynamic, dynamic>>()
                .firstWhere(
                  (item) => item['key'] == document['key'],
                  orElse: () => const <dynamic, dynamic>{},
                )
                .cast<String, dynamic>() ??
            const <String, dynamic>{};

    if (validatorMeta['name'] is String &&
        (validatorMeta['name'] as String).trim().isNotEmpty) {
      return (validatorMeta['name'] as String).trim();
    }

    if (_lang.startsWith('fr') &&
        validatorMeta['displayNameFR'] is String &&
        (validatorMeta['displayNameFR'] as String).trim().isNotEmpty) {
      return (validatorMeta['displayNameFR'] as String).trim();
    }

    if (_lang.startsWith('en') &&
        validatorMeta['displayNameEN'] is String &&
        (validatorMeta['displayNameEN'] as String).trim().isNotEmpty) {
      return (validatorMeta['displayNameEN'] as String).trim();
    }

    return DataleonLocalizations.customDocLabel(_lang, document);
  }

  List<Map<String, dynamic>> get _filteredOptions {
    final searchValue = _searchController.text.trim().toLowerCase();
    if (searchValue.isEmpty) {
      return _options;
    }
    return _options.where((option) {
      final label = (option['label'] as String? ?? '').toLowerCase();
      return label.contains(searchValue);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final dashboardConfiguration = controller.dashboardConfiguration;
    final document = _document;
    final documentName = _documentName(document);
    final title =
        (document['displayTitle'] as String?)?.trim().isNotEmpty == true
            ? (document['displayTitle'] as String).trim()
            : _t(
                'chainedDocument.title',
                fallback: _lang.startsWith('fr')
                    ? 'Chargez votre document de $documentName'
                    : 'Upload your $documentName document',
              );
    final description =
        (document['displayDescription'] as String?)?.trim().isNotEmpty == true
            ? (document['displayDescription'] as String).trim()
            : _t(
                'chainedDocument.description',
                fallback: _lang.startsWith('fr')
                    ? 'Nous avons besoin de votre document $documentName pour poursuivre la verification.'
                    : 'We need your $documentName document to continue verification.',
              );
    final helperText = _t(
      'chainedDocument.helper',
      fallback: _lang.startsWith('fr')
          ? 'Vous allez maintenant poursuivre avec ce document personnalise.'
          : 'You will now continue with this custom document.',
    );
    final selectedOption = controller.selectedChainedDocumentOption;
    final selectedOptionHelpText =
        (selectedOption?['helpText'] as String?)?.trim() ?? '';
    final selectPlaceholder = _t(
      'chainedDocument.selectPlaceholder',
      fallback: _lang.startsWith('fr')
          ? 'Aucun document disponible.'
          : 'No document available.',
    );
    final buttonColor = Color(_parseHexColor(
      dashboardConfiguration['buttonColor'] as String?,
      'FF111827',
    ));
    final buttonTextColor = Color(_parseHexColor(
      dashboardConfiguration['buttonTextColor'] as String?,
      'FFFFFFFF',
    ));

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DataleonStepHeader(
              controller: controller,
              onBack: _handleHeaderBack,
            ),
            Expanded(child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_showOptionPicker) ...[
                        const SizedBox(height: 4),
                        if (_options.isNotEmpty) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search,
                                    color: Color(0xFF9CA3AF), size: 18),
                                hintText: _lang.startsWith('fr')
                                    ? 'Rechercher un document'
                                    : 'Search a document',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _uniformColor
                                        ? _accentColor
                                        : const Color(0xFFD1D5DB),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._filteredOptions.map((option) {
                            final isSelected =
                                selectedOption?['id'] == option['id'];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () {
                                  controller
                                      .selectChainedDocumentOption(option);
                                  setState(() {
                                    _searchController.clear();
                                    _showOptionPicker = false;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFEEF2F7)
                                        : const Color(0xFFF7F7F7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected
                                        ? Border.all(
                                            color: const Color(0xFFDBE2EA),
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.description,
                                          color: Color(0xFFB8B8B8),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          (option['label'] as String?) ?? '',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        isSelected ? '✓' : '',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF868686),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (_filteredOptions.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFD1D5DB),
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Text(
                                _lang.startsWith('fr')
                                    ? 'Aucun document trouve.'
                                    : 'No document found.',
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ] else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFD1D5DB)),
                            ),
                            child: Text(
                              selectPlaceholder,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ] else ...[
                        if (_hasProposedOptions)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F7F7),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.description,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _lang.startsWith('fr')
                                            ? 'DOCUMENT CHOISI'
                                            : 'SELECTED DOCUMENT',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.6,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        (selectedOption?['label'] as String?) ??
                                            '',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _lang.startsWith('fr')
                                            ? 'Modifiez ce choix si besoin avant de continuer.'
                                            : 'Change this choice if needed before continuing.',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                TextButton(
                                  onPressed: _isUploading
                                      ? null
                                      : () {
                                          setState(() {
                                            _searchController.clear();
                                            _showOptionPicker = true;
                                          });
                                        },
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Text(
                                    _lang.startsWith('fr')
                                        ? 'Changer'
                                        : 'Change',
                                    style: const TextStyle(
                                      color: Color(0xFF334155),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (selectedOptionHelpText.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F7F7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: _uniformColor ? _accentColor : const Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    selectedOptionHelpText,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF374151),
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_shouldShowUpload &&
                            _activeMode == _ChainedDocumentMode.upload)
                          _buildUploadCard(),
                        if (!_canUseUpload)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F7F7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _lang.startsWith('fr')
                                  ? 'Cette selection se poursuit avec la camera.'
                                  : 'This selection continues with the camera.',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Color(0xFFB9B9B9),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              description.isNotEmpty ? description : helperText,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: Color(0xFF8B8B8B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_isOptionalDocument &&
                  _isSelectionResolved &&
                  !_showOptionPicker &&
                  (_canUseUpload || _canUseCamera))
                _buildSkipOptionalNotice(),
              if (_isSelectionResolved &&
                  !_showOptionPicker &&
                  (_canUseUpload || _canUseCamera))
                Container(
                  margin: EdgeInsets.only(top: _isOptionalDocument ? 6 : 12),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (_canUseUpload)
                        Expanded(
                          child: _buildModeButton(
                            label: _lang.startsWith('fr')
                                ? 'Importer le document'
                                : 'Upload document',
                            icon: Icons.cloud_upload_outlined,
                            isActive:
                                _activeMode == _ChainedDocumentMode.upload,
                            activeColor: buttonColor,
                            activeTextColor: buttonTextColor,
                            onTap: () {
                              setState(() {
                                _activeMode = _ChainedDocumentMode.upload;
                              });
                            },
                          ),
                        ),
                      if (_canUseUpload && _canUseCamera)
                        const SizedBox(width: 4),
                      if (_canUseCamera)
                        Expanded(
                          child: _buildModeButton(
                            label: _lang.startsWith('fr') ? 'Camera' : 'Camera',
                            icon: Icons.photo_camera_outlined,
                            isActive:
                                _activeMode == _ChainedDocumentMode.camera,
                            activeColor: buttonColor,
                            activeTextColor: buttonTextColor,
                            onTap: () {
                              setState(() {
                                _activeMode = _ChainedDocumentMode.camera;
                              });
                              controller.startActiveChainedDocumentCapture();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                ],          // inner Column.children
              ),            // inner Column
            )),             // Padding + Expanded
          ],                // outer Column.children
        ),                  // outer Column
      ),                    // SafeArea
    );
  }

  void _handleSkipOptionalDocument() {
    if (_isUploading) {
      return;
    }

    final selectedOptionId =
        controller.selectedChainedDocumentOption?['id']?.toString();
    final startedChainedDocument = controller.completeCurrentDocumentAndContinue(
      completedSelectedOptionId: selectedOptionId,
    );
    if (!startedChainedDocument) {
      controller.goToStep(DataleonFlowStep.success);
    }
  }

  Widget _buildSkipOptionalNotice() {
    final isFrench = _lang.startsWith('fr');
    final message = isFrench
        ? 'Ce document est optionnel, '
        : 'This document is optional, ';
    final action = isFrench ? 'cliquez ici pour passer' : 'click here to skip';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: double.infinity,
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontSize: 12,
            height: 1.35,
            color: Color(0xFF8B8B8B),
          ),
          children: [
            TextSpan(text: message),
            TextSpan(
              text: action,
              style: TextStyle(
                color: _accentColor,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: _accentColor,
              ),
              recognizer: _skipOptionalRecognizer,
            ),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(left: 3),
                child: GestureDetector(
                  onTap: _handleSkipOptionalDocument,
                  child: Icon(
                    Icons.arrow_forward,
                    size: 13,
                    color: _accentColor,
                  ),
                ),
              ),
            ),
          ],
        ),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required Color activeTextColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? activeColor : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? activeTextColor : const Color(0xFF4B5563),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isActive ? activeTextColor : const Color(0xFF4B5563),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard() {
    if (_isUploading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedFile != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedFile!.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${((_selectedFile!.size / 1024 / 1024) < 0.01 ? 0.01 : (_selectedFile!.size / 1024 / 1024)).toStringAsFixed(2)} MB',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_uploadProgress < 92 ? (_lang.startsWith('fr') ? 'Televersement en cours' : 'Upload in progress') : (_lang.startsWith('fr') ? 'Enregistrement du document' : 'Saving document')}${_loadingDots}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                Text(
                  '${_displayProgress.round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_displayProgress / 100).clamp(0, 1),
                minHeight: 6,
                backgroundColor: _uniformColor
                    ? _accentColor.withValues(alpha: 0.2)
                    : const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _uniformColor ? _accentColor : const Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _lang.startsWith('fr')
                          ? 'Importer le document'
                          : 'Upload document',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lang.startsWith('fr')
                          ? 'Ajoutez un fichier lisible au format image ou PDF.'
                          : 'Add a readable image or PDF file.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'PDF, JPG, PNG',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          if (_uploadError != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _lang.startsWith('fr')
                        ? 'Erreur de televersement'
                        : 'Upload error',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _uploadError!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          InkWell(
            onTap: _handlePickFile,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8FAFC), Colors.white],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _uniformColor
                          ? _accentColor
                          : const Color(0xFFEEF2F7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.cloud_upload_outlined,
                      size: 28,
                      color: _uniformColor
                          ? Colors.white
                          : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _parseHexColor(String? raw, String fallback) {
    final normalized =
        (raw == null || raw.isEmpty) ? fallback : raw.replaceAll('#', '');
    final withAlpha = normalized.length == 6 ? 'FF$normalized' : normalized;
    return int.tryParse(withAlpha, radix: 16) ?? int.parse(fallback, radix: 16);
  }
}

enum _ChainedDocumentMode { upload, camera }
