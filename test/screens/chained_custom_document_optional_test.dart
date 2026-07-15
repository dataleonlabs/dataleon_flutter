import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dataleon_flutter/core/dataleon_config.dart';
import 'package:dataleon_flutter/flow/dataleon_flow_controller.dart';
import 'package:dataleon_flutter/screens/chained_custom_document_step_page.dart';

/// Le texte « Ce document est optionnel, cliquez ici pour passer » ne doit
/// apparaître que sur les documents portant explicitement `required: false`.
void main() {
  late DataleonFlowController controller;

  tearDown(() => controller.dispose());

  Future<void> pumpWithDocument(
    WidgetTester tester,
    Map<String, dynamic> document,
  ) async {
    controller = DataleonFlowController(
      config: DataleonConfig(
        sessionId: 'sid',
        token: 'jwt',
        initialLanguage: 'fr',
      ),
    );
    controller.beginChainedDocument(document);

    await tester.pumpWidget(
      MaterialApp(
        // La page n'a pas de Scaffold : c'est DataleonFlowScreen qui le fournit
        // en production. Sans ancêtre Material, ses InkWell lèvent une
        // assertion.
        home: Scaffold(
          body: ChainedCustomDocumentStepPage(controller: controller),
        ),
      ),
    );
    await tester.pump();
  }

  Finder noticeFinder() =>
      find.textContaining('optionnel', findRichText: true);

  // Document sans proposedOptions (sélection résolue d'office) et avec upload
  // activé, pour que la rangée de boutons — et donc la zone où le texte
  // s'insère — soit rendue.
  Map<String, dynamic> baseDocument({Object? required}) => {
        'key': 'kyb_doc',
        'uploadEnabled': true,
        if (required != null) 'required': required,
      };

  testWidgets('affiche le texte quand required vaut false', (tester) async {
    await pumpWithDocument(tester, baseDocument(required: false));
    expect(noticeFinder(), findsOneWidget);
  });

  testWidgets('masque le texte quand required vaut true', (tester) async {
    await pumpWithDocument(tester, baseDocument(required: true));
    expect(noticeFinder(), findsNothing);
  });

  testWidgets('masque le texte quand required est absent', (tester) async {
    await pumpWithDocument(tester, baseDocument());
    expect(noticeFinder(), findsNothing);
  });

  testWidgets('masque le texte quand required est la chaine "false"',
      (tester) async {
    // Un `required` non booléen ne doit jamais ouvrir le skip : on préfère
    // demander un document de trop que d'en sauter un obligatoire.
    await pumpWithDocument(tester, baseDocument(required: 'false'));
    expect(noticeFinder(), findsNothing);
  });
}
