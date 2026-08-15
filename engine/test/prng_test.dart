import 'package:minedoku_engine/minedoku_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Prng', () {
    test('the same seed replays the same sequence', () {
      final a = Prng(12345);
      final b = Prng(12345);
      for (var i = 0; i < 200; i++) {
        expect(a.nextInt(1000), b.nextInt(1000));
      }
    });

    test('different seeds diverge immediately', () {
      final a = Prng(1);
      final b = Prng(2);
      final first = [for (var i = 0; i < 10; i++) a.nextInt(100)];
      final second = [for (var i = 0; i < 10; i++) b.nextInt(100)];
      expect(first, isNot(second));
    });

    test('nextInt stays inside its range', () {
      final random = Prng(7);
      for (var i = 0; i < 5000; i++) {
        final value = random.nextInt(6);
        expect(value, inInclusiveRange(0, 5));
      }
    });

    test('nextInt covers its whole range', () {
      final random = Prng(11);
      final seen = <int>{};
      for (var i = 0; i < 2000; i++) {
        seen.add(random.nextInt(6));
      }
      expect(seen, {0, 1, 2, 3, 4, 5});
    });

    test('nextDouble stays in [0, 1)', () {
      final random = Prng(3);
      for (var i = 0; i < 2000; i++) {
        final value = random.nextDouble();
        expect(value, greaterThanOrEqualTo(0.0));
        expect(value, lessThan(1.0));
      }
    });

    test('nextInt rejects a non-positive bound', () {
      expect(() => Prng(1).nextInt(0), throwsArgumentError);
    });

    test('shuffle keeps every element', () {
      final items = List<int>.generate(50, (i) => i);
      Prng(9).shuffle(items);
      expect(items.toSet(), List<int>.generate(50, (i) => i).toSet());
      expect(items, isNot(List<int>.generate(50, (i) => i)));
    });

    test('pickWeighted honours the weights', () {
      final random = Prng(5);
      var zeros = 0;
      for (var i = 0; i < 1000; i++) {
        if (random.pickWeighted([9.0, 1.0]) == 0) zeros++;
      }
      expect(zeros, greaterThan(800));
      expect(zeros, lessThan(1000));
    });

    test('pickWeighted never returns a zero-weight index', () {
      final random = Prng(17);
      for (var i = 0; i < 500; i++) {
        expect(random.pickWeighted([0.0, 1.0, 0.0]), 1);
      }
    });
  });
}
