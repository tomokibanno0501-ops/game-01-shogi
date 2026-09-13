import 'package:flutter_test/flutter_test.dart';
import 'package:yuru_syougi/models/piece.dart';
import 'package:yuru_syougi/models/shogi_board.dart';

void _clear(ShogiBoard board) {
  for (var row = 0; row < 9; row++) {
    for (var col = 0; col < 9; col++) {
      board.squares[row][col] = null;
    }
  }
}

void main() {
  group('成りの判定', () {
    test('敵陣に入る手は成るかどうかを選択できる', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
      board.squares[3][4] = const Piece(PieceType.gin, Owner.sente);

      expect(board.canPromote(const Square(3, 4), const Square(2, 4)), isTrue);
      expect(board.mustPromote(const Square(3, 4), const Square(2, 4)), isFalse);
    });

    test('敵陣外での移動は成りの対象にならない', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
      board.squares[5][4] = const Piece(PieceType.gin, Owner.sente);

      expect(board.canPromote(const Square(5, 4), const Square(4, 4)), isFalse);
    });

    test('金・玉は成れない', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
      board.squares[3][4] = const Piece(PieceType.kin, Owner.sente);

      expect(board.canPromote(const Square(3, 4), const Square(2, 4)), isFalse);
    });

    test('歩が最奥段に進む手は強制的に成りとなる', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
      board.squares[1][4] = const Piece(PieceType.fu, Owner.sente);

      expect(board.mustPromote(const Square(1, 4), const Square(0, 4)), isTrue);
      // 強制成りの手自体は合法手として残っている
      expect(board.legalDestinations(const Square(1, 4)),
          contains(const Square(0, 4)));
    });

    test('桂が最奥2段に進む手は強制的に成りとなる', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
      board.squares[2][4] = const Piece(PieceType.kei, Owner.sente);

      expect(board.mustPromote(const Square(2, 4), const Square(0, 3)), isTrue);
    });
  });

  group('成り駒の移動', () {
    test('と金は金と同じ動きをする（斜め後ろには進めない）', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
      board.squares[4][4] =
          const Piece(PieceType.fu, Owner.sente, promoted: true);

      final dests = board.legalDestinations(const Square(4, 4));

      expect(dests, containsAll([
        const Square(3, 4), // 前
        const Square(4, 3), // 横
        const Square(4, 5), // 横
        const Square(5, 4), // 後ろ（金は後退可）
      ]));
      expect(dests.contains(const Square(5, 3)), isFalse); // 斜め後ろは不可
      expect(dests.contains(const Square(5, 5)), isFalse);
    });

    test('龍（成り飛車）は前後左右のスライドに加えて斜め一マスに進める', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
      board.squares[4][4] =
          const Piece(PieceType.hisha, Owner.sente, promoted: true);

      final dests = board.legalDestinations(const Square(4, 4));

      expect(dests.contains(const Square(3, 3)), isTrue); // 斜め一マス
      expect(dests.contains(const Square(0, 4)), isTrue); // 縦スライド
      expect(dests.contains(const Square(2, 3)), isFalse); // 斜め2マスは不可
    });

    test('馬（成り角）は斜めのスライドに加えて前後左右一マスに進める', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
      board.squares[4][4] =
          const Piece(PieceType.kaku, Owner.sente, promoted: true);

      final dests = board.legalDestinations(const Square(4, 4));

      expect(dests.contains(const Square(3, 4)), isTrue); // 前一マス
      expect(dests.contains(const Square(0, 0)), isTrue); // 斜めスライド
      expect(dests.contains(const Square(2, 4)), isFalse); // 前2マスは不可
    });
  });

  group('駒を取ったときの持ち駒', () {
    test('成り駒を取ると持ち駒には不成の駒種として加わる', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
      board.squares[4][4] =
          const Piece(PieceType.hisha, Owner.sente, promoted: true);
      board.squares[3][4] = const Piece(PieceType.kaku, Owner.gote);

      board.movePiece(const Square(4, 4), const Square(3, 4));

      expect(board.handCount(Owner.sente, PieceType.kaku), 1);
    });
  });
}
