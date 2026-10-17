import 'dart:io';

import 'package:boundarylens_cli/src/config_loader.dart';
import 'package:boundarylens_cli/src/rules/lifecycle_resource.dart';
import 'package:boundarylens_cli/src/static_issue.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  setUp(() => directory = Directory.systemTemp.createTempSync('fg_lifecycle_'));
  tearDown(() => directory.deleteSync(recursive: true));

  List<StaticIssue> scan(String source, {bool enabled = true}) {
    final file = File('${directory.path}/input.dart')
      ..writeAsStringSync(source);
    return LifecycleResourceRule(
      RuleConfig(enabled: enabled, severity: RiskLevel.medium),
    ).analyze([file.path]);
  }

  test('nullable generic subscription and nullable timer require cleanup', () {
    final issues = scan('''
class Owner {
  StreamSubscription<int>? subscription;
  Timer? timer;
  void initState() {
    subscription = events.listen((_) {});
    timer = Timer.periodic(Duration(seconds: 1), (_) {});
  }
}
''');
    expect(issues.map((i) => i.metadata['fieldName']), [
      'subscription',
      'timer',
    ]);
    expect(issues.every((i) => i.level == RiskLevel.medium), isTrue);
  });

  test('all variables in a field declaration are checked', () {
    final issues = scan('''
class Owner {
  late Timer first, second;
  void dispose() { first.cancel(); }
}
''');
    expect(issues.single.metadata['fieldName'], 'second');
  });

  test('strings mentioning cancel are not cleanup calls', () {
    final issues = scan('''
class Owner {
  late Timer timer;
  void dispose() { print('timer.cancel()'); }
}
''');
    expect(issues, hasLength(1));
  });

  test('null-aware, this and cascade cleanup calls are recognized', () {
    expect(
      scan('''
class Owner {
  Timer? first;
  late Timer second, third;
  void dispose() {
    first?.cancel();
    this.second.cancel();
    third..cancel();
  }
}
'''),
      isEmpty,
    );
  });

  test('same-class delegated cleanup and helper cycles are bounded', () {
    expect(
      scan('''
class Owner {
  Timer? timer;
  void dispose() { release(); }
  void release() { timer?.cancel(); other(); }
  void other() { release(); }
}
'''),
      isEmpty,
    );
  });

  test('an uncalled cleanup method does not release the resource', () {
    expect(
      scan('''
class Owner {
  late Timer timer;
  void dispose() {}
  void release() { timer.cancel(); }
}
'''),
      hasLength(1),
    );
  });

  test('a stored callback is not an executed cleanup', () {
    expect(
      scan('''
class Owner {
  late Timer timer;
  void dispose() { final later = () => timer.cancel(); }
}
'''),
      hasLength(1),
    );
  });

  test('resource containers are not treated as a single resource', () {
    expect(scan('class Owner { late List<Timer> timers; }'), isEmpty);
  });

  test(
    'initState with a one-shot post-frame callback needs no dispose pair',
    () {
      expect(
        scan('''
class Owner extends State<Page> {
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { bootstrap(); });
  }
}
'''),
        isEmpty,
      );
    },
  );

  test('disabled lifecycle rule stays silent', () {
    expect(scan('class Owner { Timer? timer; }', enabled: false), isEmpty);
  });
}
