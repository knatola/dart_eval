import 'package:dart_eval/dart_eval.dart';
import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:dart_eval/src/eval/shared/stdlib/core/base.dart';
import 'package:dart_eval/src/eval/shared/stdlib/core/collection.dart';
import 'package:dart_eval/src/eval/shared/stdlib/core/future.dart';
import 'package:dart_eval/src/eval/shared/stdlib/core/num.dart';
import 'package:test/test.dart';

/// Regression tests for num/double type-coercion and nullable-cast fixes:
///  - `num / num` must return `double` (Dart spec), was inferred `num`
///  - `num ~/ num` must return `int` (Dart spec), was inferred `num`
///  - `null as T?` must succeed (yield null), was throwing TypeError
void main() {
  late Compiler compiler;
  setUp(() => compiler = Compiler());

  num asNum(dynamic v) => (v is $Value ? v.$value : v) as num;
  dynamic asRaw(dynamic v) => v is $Value ? v.$value : v;

  group('num / num -> double', () {
    test('division of two num params returned as double', () {
      final runtime = compiler.compileWriteAndLoad({
        'example': {
          'main.dart': '''
            double calc(num a, num b) => a / b;
            dynamic main() => calc(10, 4);
          ''',
        },
      });
      expect(
        asNum(runtime.executeLib('package:example/main.dart', 'main')),
        2.5,
      );
    });

    test('composite slope expression (num arithmetic then divide)', () {
      final runtime = compiler.compileWriteAndLoad({
        'example': {
          'main.dart': '''
            double calculateSlope(num y2, num y1, num x2, num x1) => (y2 - y1) / (x2 - x1);
            dynamic main() => calculateSlope(10, 2, 4, 2);
          ''',
        },
      });
      expect(
        asNum(runtime.executeLib('package:example/main.dart', 'main')),
        4.0,
      );
    });

    test('int / int still returns double (no regression)', () {
      final runtime = compiler.compileWriteAndLoad({
        'example': {
          'main.dart': '''
            double main() => 10 / 4;
          ''',
        },
      });
      expect(
        asNum(runtime.executeLib('package:example/main.dart', 'main')),
        2.5,
      );
    });

    test('double / num still returns double (no regression)', () {
      final runtime = compiler.compileWriteAndLoad({
        'example': {
          'main.dart': '''
            double calc(double a, num b) => a / b;
            dynamic main() => calc(10.0, 4);
          ''',
        },
      });
      expect(
        asNum(runtime.executeLib('package:example/main.dart', 'main')),
        2.5,
      );
    });
  });

  group('num ~/ num -> int', () {
    test('integer division of two num params returned as int', () {
      final runtime = compiler.compileWriteAndLoad({
        'example': {
          'main.dart': '''
            int calc(num a, num b) => a ~/ b;
            dynamic main() => calc(10, 3);
          ''',
        },
      });
      expect(asNum(runtime.executeLib('package:example/main.dart', 'main')), 3);
    });
  });

  group('null as T?', () {
    test('null as num? ?? default yields default', () {
      final runtime = compiler.compileWriteAndLoad({
        'example': {
          'main.dart': '''
            dynamic main() {
              final m = <String, dynamic>{};
              return (m['x'] as num?) ?? 0;
            }
          ''',
        },
      });
      expect(asNum(runtime.executeLib('package:example/main.dart', 'main')), 0);
    });

    test('non-null as num? ?? default yields the value', () {
      final runtime = compiler.compileWriteAndLoad({
        'example': {
          'main.dart': '''
            dynamic main() {
              final m = {'x': 42};
              return (m['x'] as num?) ?? 0;
            }
          ''',
        },
      });
      expect(
        asNum(runtime.executeLib('package:example/main.dart', 'main')),
        42,
      );
    });

    test('null as String? ?? default yields default', () {
      final runtime = compiler.compileWriteAndLoad({
        'example': {
          'main.dart': '''
            dynamic main() {
              final m = <String, dynamic>{};
              return (m['x'] as String?) ?? 'dflt';
            }
          ''',
        },
      });
      expect(
        asRaw(runtime.executeLib('package:example/main.dart', 'main')),
        'dflt',
      );
    });

    test('as T? still throws on a genuinely wrong type', () {
      final runtime = compiler.compileWriteAndLoad({
        'example': {
          'main.dart': '''
            dynamic main() {
              final m = {'x': 'not a num'};
              return (m['x'] as num?) ?? 0;
            }
          ''',
        },
      });
      expect(
        () => runtime.executeLib('package:example/main.dart', 'main'),
        throwsA(predicate((e) => e.toString().contains('Not a subtype'))),
      );
    });
  });

  group('null is T', () {
    test(
      'missing map value follows nullable and non-nullable type semantics',
      () {
        final runtime = compiler.compileWriteAndLoad({
          'example': {
            'main.dart': '''
            int main() {
              final m = <String, dynamic>{};
              var result = 0;
              if (m['x'] is num) result += 1;
              if (m['x'] is! num) result += 2;
              if (m['x'] is num?) result += 4;
              if (m['x'] is! num?) result += 8;
              return result;
            }
          ''',
          },
        });

        expect(
          asNum(runtime.executeLib('package:example/main.dart', 'main')),
          6,
        );
      },
    );
  });

  test('bridged async named-argument query values cast to num', () async {
    final runtime = compiler.compileWriteAndLoad({
      'example': {
        'main.dart': '''
          Function tool = (name, args) {};

          Future<dynamic> metric_query({
            required List<String> metrics,
            Map<String, dynamic>? dateRange,
            List<Map<String, dynamic>>? filters,
            String? rollupType,
            String? rollupTimeframe,
            int? limit,
            String? orderBy,
            String? orderDirection,
          }) async {
            final args = <String, dynamic>{};
            args['metrics'] = metrics;
            if (dateRange != null) args['dateRange'] = dateRange;
            if (filters != null) args['filters'] = filters;
            if (rollupType != null) args['rollupType'] = rollupType;
            if (rollupTimeframe != null) args['rollupTimeframe'] = rollupTimeframe;
            if (limit != null) args['limit'] = limit;
            if (orderBy != null) args['orderBy'] = orderBy;
            if (orderDirection != null) args['orderDirection'] = orderDirection;
            return await tool('metric_query', args);
          }

          Future<Map<String, dynamic>> userMain() async {
            final rows = await metric_query(metrics: ['integer', 'decimal']);
            final validRows = <Map<String, dynamic>>[];
            for (final row in rows) {
              if (row['integer'] != null && row['decimal'] != null) {
                validRows.add(row);
              }
            }

            num total = 0;
            for (final row in validRows) {
              final integer = row['integer'] as num;
              final decimal = row['decimal'] as num;
              total += integer + decimal;
            }
            return {'total': total};
          }

          dynamic runMain(Function callback) async {
            tool = callback;
            return await userMain();
          }
        ''',
      },
    });
    final rows = $List.wrap([
      $Map.wrap({
        $String('integer'): $int(42),
        $String('decimal'): $double(0.5),
      }),
      $Map.wrap({$String('integer'): $int(7)}),
      $Map.wrap({
        $String('integer'): $int(8),
        $String('decimal'): $double(1.5),
      }),
    ]);
    final callback = $Closure((runtime, target, args) {
      return $Future.wrap(Future.value(rows));
    });

    final result = runtime.executeLib('package:example/main.dart', 'runMain', [
      callback,
    ]);
    expect(result, isA<$Future>());
    final value = await (result as $Future).$value as $Map;
    expect(asNum(value.$value[$String('total')]), 52);
  });
}
