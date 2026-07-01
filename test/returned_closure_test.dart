import 'package:dart_eval/dart_eval.dart';
import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:test/test.dart';

/// Regression test for calling a variable that holds a closure returned from
/// a function call. Previously threw: "Cannot call X as it is not a valid
/// method" because the variable's type was inferred as dynamic, not Function.
void main() {
  late Compiler compiler;
  setUp(() => compiler = Compiler());

  dynamic asRaw(dynamic v) => v is $Value ? v.$value : v;

  test('local fn (block body) returns closure, called via variable', () {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          dynamic main() {
            Function adder(int n) { return (int x) => x + n; }
            final add5 = adder(5);
            return add5(10);
          }
        ''',
      },
    });
    expect(asRaw(runtime.executeLib('package:example/main.dart', 'main')), 15);
  });

  test('local fn (arrow body) returns closure, called via variable', () {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          dynamic main() {
            Function adder(int n) => (int x) => x + n;
            final a = adder(5);
            return a(10);
          }
        ''',
      },
    });
    expect(asRaw(runtime.executeLib('package:example/main.dart', 'main')), 15);
  });

  test('chained immediate call still works (no regression)', () {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          dynamic main() {
            Function adder(int n) => (int x) => x + n;
            return adder(7)(3);
          }
        ''',
      },
    });
    expect(asRaw(runtime.executeLib('package:example/main.dart', 'main')), 10);
  });

  test('closure literal in variable, called (no regression)', () {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          dynamic main() {
            final f = (int x) => x * 2;
            return f(21);
          }
        ''',
      },
    });
    expect(asRaw(runtime.executeLib('package:example/main.dart', 'main')), 42);
  });

  test('returned closure captures variable from enclosing scope', () {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          dynamic main() {
            dynamic makeMultiplier(int factor) {
              return (int x) => x * factor;
            }
            final triple = makeMultiplier(3);
            return triple(14);
          }
        ''',
      },
    });
    expect(asRaw(runtime.executeLib('package:example/main.dart', 'main')), 42);
  });

  test('dynamic-typed variable holding closure, called', () {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          dynamic main() {
            dynamic f = (int x) => x + 1;
            return f(41);
          }
        ''',
      },
    });
    expect(asRaw(runtime.executeLib('package:example/main.dart', 'main')), 42);
  });
}
