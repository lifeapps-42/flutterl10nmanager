import 'dart:io';
import 'dart:convert';
import 'package:args/command_runner.dart';
import 'package:flutterl10nmanager/constants/special_symbols.dart';
import 'package:flutterl10nmanager/entities/localisation.dart';
import 'package:flutterl10nmanager/manager.dart';
import 'package:flutterl10nmanager/helpers.dart';

/// Exports the current Flutter internationalisation files to a singl CSV
/// so that all translations can be worked on in on document. Once translation is
/// complete, you can then use [CreateCommand] to generate new arb files to use
/// in your Flutter project.
class ExportCommand extends Command {
  final name = 'export';
  final description = 'Exports the current translations to a single CSV';

  final _log = Logger();

  ExportCommand() {
    argParser.addOption('output-path',
        abbr: 'o',
        help: 'A path to the desired output location',
        defaultsTo: './flutterl10n-export.csv');
  }

  void run() async {
    final l10nPath =
        argResults!.rest[0].endsWith('/') || argResults!.rest[0].endsWith('\\')
            ? argResults?.rest[0]
            : argResults!.rest[0] + '/';
    // Validate the path
    if (l10nPath == null) {
      _log.error('No path provided.');
      return;
    }
    if (FileSystemEntity.typeSync(
            l10nPath + LocalisationsManager.messageFileName) ==
        FileSystemEntityType.notFound) {
      _log.error(
          'Unable to find a flutter message file in the given dir. Giving up.');
      return;
    }

    // Start a new instance of the manager
    LocalisationsManager manager = LocalisationsManager();
    // Create the resources
    await File(l10nPath + LocalisationsManager.messageFileName)
        .readAsString()
        .then((fileContents) => jsonDecode(fileContents))
        .then((jsonData) {
      jsonData.keys.forEach((String e) {
        if (e.startsWith('@') &&
            LocalisationsManager.isValidResourceObject(jsonData[e])) {
          manager.addLocalisation(Localisation(
            id: e.substring(1),
            description: jsonData[e]['description'] ?? '',
            type: jsonData[e]['type'] ?? '',
            placeholders: jsonData[e]['placeholders'] ?? '',
          ));
        } else {
          manager.addLocalisation(Localisation(
              id: e, description: "", type: "", placeholders: null));
        }
      });
    });

    // Now find all the language specific files
    Directory dir = Directory(l10nPath);
    Map<String, String> localisationFiles = {};
    dir.listSync().forEach((f) {
      final fileName = getFileNameFromPath(f.path);
      var pattern = RegExp(r'app_([a-z]{0,3})\.arb');
      if (pattern.hasMatch(fileName)) {
        if (pattern.firstMatch(fileName)?.group(1) != null) {
          final match = pattern.firstMatch(fileName)!;
          localisationFiles[match.group(1)!] = fileName;
        }
      }
    });

    for (String lang in localisationFiles.keys) {
      await File(l10nPath + localisationFiles[lang]!)
          .readAsString()
          .then((fileContents) => jsonDecode(fileContents))
          .then((jsonData) {
        jsonData.keys.forEach((String e) {
          if (e.startsWith('@')) {
            return;
          }
          manager.addValueForLocalisation(lang, e, jsonData[e]);
        });
      });
    }

    String exportName = argResults?['output-path'];
    _log.info('Export Started');
    await File(exportName).writeAsString(
      'sep=$columnDelimeter\r\n',
    );
    await File(exportName)
        .writeAsString(manager.getAsCSV(), mode: FileMode.append);
    _log.success("Successfully exported data to CSV: ${exportName}");
  }
}
