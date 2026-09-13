import 'package:flutter_test/flutter_test.dart';
import 'package:yuru_syougi/models/piece.dart';
import 'package:yuru_syougi/models/shogi_board.dart';

/// 盤面をすべて空にする（王を含め、テストごとに必要な駒だけを配置するため）。
void _clear(ShogiBoard board) {
  for (var row = 0; row < 9; row++) {
    for (var col = 0; col < 9; col++) {
      board.squares[row][col] = null;
    }
  }
}

void main() {
  group('二歩', () {
    test('自分の歩がある筋への歩打ちは禁止される', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
      board.squares[6][4] = const Piece(PieceType.fu, Owner.sente);
      board.hands[Owner.sente]![PieceType.fu] = 1;

      final drops = board.legalDropSquares(Owner.sente, PieceType.fu);

      expect(drops.any((s) => s.col == 4), isFalse);
      expect(drops.any((s) => s.col == 0), isTrue);
    });

    test('と金がある筋は二歩にならず、歩を打てる（見落としやすい例外）', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
      // 4筋にあるのは「と金」であり「歩」ではないため、二歩の制約を受けない
      board.squares[6][4] =
          const Piece(PieceType.fu, Owner.sente, promoted: true);
      board.hands[Owner.sente]![PieceType.fu] = 1;

      final drops = board.legalDropSquares(Owner.sente, PieceType.fu);

      expect(drops.any((s) => s.col == 4), isTrue);
    });
  });

  group('行き所のない駒', () {
    test('歩・香が最奥段へ進む手は、成る前提でのみ許される（強制成り）', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
      board.squares[1][4] = const Piece(PieceType.fu, Owner.sente);

      final dests = board.legalDestinations(const Square(1, 4));

      expect(dests, [const Square(0, 4)]);
      expect(board.mustPromote(const Square(1, 4), const Square(0, 4)), isTrue);
    });

    test('桂は最奥2段へ打てない', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
      board.hands[Owner.sente]![PieceType.kei] = 1;

      final drops = board.legalDropSquares(Owner.sente, PieceType.kei);

      expect(drops.any((s) => s.row == 0 || s.row == 1), isFalse);
      expect(drops.any((s) => s.row == 2), isTrue);
    });

    test('香は最奥段へ打てない', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
      board.hands[Owner.sente]![PieceType.kyo] = 1;

      final drops = board.legalDropSquares(Owner.sente, PieceType.kyo);

      expect(drops.any((s) => s.row == 0), isFalse);
      expect(drops.any((s) => s.row == 1), isTrue);
    });
  });

  group('王手放置', () {
    test('動かすと自玉が飛車の利きにさらされる駒は、筋を外れる移動ができない', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[8][4] = const Piece(PieceType.ou, Owner.sente);
      board.squares[7][4] = const Piece(PieceType.kin, Owner.sente);
      board.squares[0][4] = const Piece(PieceType.hisha, Owner.gote);
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);

      final dests = board.legalDestinations(const Square(7, 4));

      // 4筋に留まる (6,4) 以外は王手放置となり除外される
      expect(dests, [const Square(6, 4)]);
    });
  });

  group('王手放置（持ち駒を打つ手）', () {
    test('王手を防がない持ち駒の打ち手は禁止され、合い駒になる打ち手だけが残る', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[8][4] = const Piece(PieceType.ou, Owner.sente);
      board.squares[0][4] = const Piece(PieceType.hisha, Owner.gote);
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
      board.hands[Owner.sente]![PieceType.kin] = 1;

      final drops = board.legalDropSquares(Owner.sente, PieceType.kin);

      // 飛車の利き（4筋）を遮る(1,4)〜(7,4)以外はすべて王手放置となり除外される
      expect(
        drops.toSet(),
        {for (var row = 1; row <= 7; row++) Square(row, 4)},
      );
    });
  });

  group('打ち歩詰め', () {
    test('玉に逃げ場がなく捕獲もできない歩打ちは禁止される', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
      board.squares[0][1] = const Piece(PieceType.kyo, Owner.gote);
      board.squares[1][1] = const Piece(PieceType.kei, Owner.gote);
      board.squares[8][0] = const Piece(PieceType.kyo, Owner.sente);
      board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);
      board.hands[Owner.sente]![PieceType.fu] = 1;

      final drops = board.legalDropSquares(Owner.sente, PieceType.fu);

      expect(drops.contains(const Square(1, 0)), isFalse);
    });

    test('玉に逃げ場がある場合は歩打ちで王手をかけてよい', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
      board.squares[0][1] = const Piece(PieceType.kyo, Owner.gote);
      // (1,1) を空けて玉の逃げ場を残す
      board.squares[8][0] = const Piece(PieceType.kyo, Owner.sente);
      board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);
      board.hands[Owner.sente]![PieceType.fu] = 1;

      final drops = board.legalDropSquares(Owner.sente, PieceType.fu);

      expect(drops.contains(const Square(1, 0)), isTrue);
    });
  });
}
