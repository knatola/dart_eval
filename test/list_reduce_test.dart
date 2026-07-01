import 'package:dart_eval/dart_eval.dart';
import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:test/test.dart';

/// Regression test for List.reduce closure bridge.
/// Previously threw: type '(dynamic, dynamic) => $Value?' is not a subtype
/// of type '($Value, $Value) => $Value' of 'combine'.
///
/// Note: dart_eval returns reduce results of primitive lists unboxed
/// (raw int/double) while object lists (e.g. String) stay boxed ($String).
/// The helpers below normalize both so the assertions are stable.
void main() {
  late Compiler compiler;
  setUp(() => compiler = Compiler());

  num asNum(dynamic v) => (v is $Value ? v.$value : v) as num;
  dynamic asRaw(dynamic v) => v is $Value ? v.$value : v;

  test('reduce int list with closure', () {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          int main() {
            return [1, 2, 3, 4].reduce((a, b) => a + b);
          }
        ''',
      },
    });
    expect(asNum(runtime.executeLib('package:example/main.dart', 'main')), 10);
  });

  test('reduce with block-bodied closure', () {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          int main() {
            final list = [3, 1, 4, 1, 5];
            return list.reduce((a, b) {
              if (a > b) { return a; }
              return b;
            });
          }
        ''',
      },
    });
    expect(asNum(runtime.executeLib('package:example/main.dart', 'main')), 5);
  });

  test('reduce double list', () {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          double main() {
            return [1.5, 2.5, 3.0].reduce((a, b) => a + b);
          }
        ''',
      },
    });
    expect(asNum(runtime.executeLib('package:example/main.dart', 'main')), 7.0);
  });

  test('reduce string list concatenation', () {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          String main() {
            return ['a', 'b', 'c'].reduce((a, b) => a + b);
          }
        ''',
      },
    });
    expect(
      asRaw(runtime.executeLib('package:example/main.dart', 'main')),
      'abc',
    );
  });

  test('reduce on iterable from map (chained)', () {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          int main() {
            final values = [1, 2, 3].map((e) => e * 10);
            return values.reduce((a, b) => a + b);
          }
        ''',
      },
    });
    expect(asNum(runtime.executeLib('package:example/main.dart', 'main')), 60);
  });

  test('reduce throws on empty list', () {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          int main() {
            return <int>[].reduce((a, b) => a + b);
          }
        ''',
      },
    });
    // reduce on empty throws StateError, mirroring Dart semantics
    expect(
      () => runtime.executeLib('package:example/main.dart', 'main'),
      throwsA(isA<StateError>()),
    );
  });
}
