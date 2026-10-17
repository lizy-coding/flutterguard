import 'dart:io';

import 'package:args/args.dart';
import 'package:boundarylens_cli/src/cli/baseline_commands.dart';
import 'package:boundarylens_cli/src/cli/cli_parsers.dart';
import 'package:boundarylens_cli/src/cli/config_commands.dart';
import 'package:boundarylens_cli/src/cli/rule_commands.dart';
import 'package:boundarylens_cli/src/cli/scan_command.dart';

const _version = '0.7.1';

void main(List<String> args) {
  final parsers = CliParsers();
  try {
    final result = parsers.root.parse(args);
    if (result['version'] == true) {
      stdout.writeln('boundarylens $_version');
      return;
    }
    if (args.isEmpty || result['help'] == true || result.command == null) {
      _usage(parsers.root);
      return;
    }

    final command = result.command!;
    switch (command.name) {
      case 'scan':
        if (_help(command, parsers.scan, 'boundarylens scan [path]')) return;
        ScanCommand.run(command, configPath: _explicitConfigPath(command));
        return;
      case 'baseline':
        final leaf = command.command;
        if (command['help'] == true || leaf == null) {
          _subcommandUsage(
            'boundarylens baseline create [path]',
            parsers.baseline,
          );
          return;
        }
        if (_help(
          leaf,
          parsers.baselineCreate,
          'boundarylens baseline create [path]',
        )) {
          return;
        }
        BaselineCommands.create(leaf, configPath: _explicitConfigPath(leaf));
        return;
      case 'config':
        final leaf = command.command;
        if (command['help'] == true || leaf == null) {
          _subcommandUsage(
            'boundarylens config <init|check> [path]',
            parsers.config,
          );
          return;
        }
        if (leaf.name == 'init') {
          if (_help(
            leaf,
            parsers.configInit,
            'boundarylens config init [path]',
          )) {
            return;
          }
          ConfigCommands.init(leaf);
          return;
        }
        if (_help(
          leaf,
          parsers.configCheck,
          'boundarylens config check [path]',
        )) {
          return;
        }
        ConfigCommands.check(leaf, configPath: _explicitConfigPath(leaf));
        return;
      case 'rules':
        if (_help(command, parsers.rules, 'boundarylens rules [rule-id]')) {
          return;
        }
        RuleCommands.run(command);
        return;
    }
  } on FormatException catch (error) {
    stderr.writeln('Error: ${error.message}');
    exitCode = 2;
  }
}

bool _help(ArgResults args, ArgParser parser, String usage) {
  if (args['help'] != true) return false;
  _subcommandUsage(usage, parser);
  return true;
}

String? _explicitConfigPath(ArgResults args) =>
    args.wasParsed('config') ? args['config'] as String : null;

void _usage(ArgParser parser) {
  stdout.writeln('BoundaryLens — Dart project module boundary checks');
  stdout.writeln('Usage: boundarylens <command> [options]');
  stdout.writeln();
  stdout.writeln('Commands: scan, baseline, config, rules');
  stdout.writeln(parser.usage);
}

void _subcommandUsage(String usage, ArgParser parser) {
  stdout.writeln('Usage: $usage');
  stdout.writeln(parser.usage);
}
