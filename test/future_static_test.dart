import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:dart_eval/dart_eval.dart';
import 'package:test/test.dart';

/// Regression tests for Future.value / Future.forEach / Future.wait static
/// methods, which were previously unbridged ("Cannot find static method").
void main() {
  late Compiler compiler;
  setUp(() => compiler = Compiler());

  dynamic asRaw(dynamic v) => v is $Value ? v.$value : v;

  test('Future.value returns a completed future', () async {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          Future<dynamic> main() async {
            return Future.value(5);
          }
        ''',
      },
    });
    final result = await runtime.executeLib(
      'package:example/main.dart',
      'main',
    );
    expect(asRaw(result), 5);
  });

  test('await Future.value', () async {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          Future<dynamic> main() async {
            final v = await Future.value(42);
            return v;
          }
        ''',
      },
    });
    final result = await runtime.executeLib(
      'package:example/main.dart',
      'main',
    );
    expect(asRaw(result), 42);
  });

  test('Future.value with a String', () async {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          Future<dynamic> main() async {
            return Future.value('hello');
          }
        ''',
      },
    });
    final result = await runtime.executeLib(
      'package:example/main.dart',
      'main',
    );
    expect(asRaw(result), 'hello');
  });

  test('Future.forEach sums via async action', () async {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          Future<dynamic> main() async {
            var sum = 0;
            await Future.forEach([1, 2, 3], (e) async { sum += e; });
            return sum;
          }
        ''',
      },
    });
    final result = await runtime.executeLib(
      'package:example/main.dart',
      'main',
    );
    expect(asRaw(result), 6);
  });

  test('Future.wait collects results', () async {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          Future<dynamic> main() async {
            final results = await Future.wait([Future.value(1), Future.value(2), Future.value(3)]);
            return results.length;
          }
        ''',
      },
    });
    final result = await runtime.executeLib(
      'package:example/main.dart',
      'main',
    );
    expect(asRaw(result), 3);
  });

  test('Future.value nested in Future.wait', () async {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          Future<dynamic> main() async {
            final f = Future.value(10);
            final r = await Future.wait([f]);
            return r;
          }
        ''',
      },
    });
    final result = await runtime.executeLib(
      'package:example/main.dart',
      'main',
    );
    // Result is a List of resolved values
    expect(result, isNotNull);
  });
}
