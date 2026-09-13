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
  group('詰みの判定', () {
    test('挟み金による詰み: 玉に逃げ場がなく合法手が一つもない', () {
      final board = ShogiBoard();
      _clear(board);
      // 後手玉(0,0)が金(1,0)・金(1,1)に囲まれ、飛車(0,1)で王手されている典型的な詰み形。
      board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
      board.squares[1][0] = const Piece(PieceType.kin, Owner.sente);
      board.squares[1][1] = const Piece(PieceType.kin, Owner.sente);
      board.squares[0][1] = const Piece(PieceType.hisha, Owner.sente);
      board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);

      expect(board.isInCheck(Owner.gote), isTrue);
      expect(board.isCheckmate(Owner.gote), isTrue);
      expect(board.legalMoves(Owner.gote), isEmpty);
    });

    test('王手されていても逃げ場があれば詰みではない', () {
      final board = ShogiBoard();
      _clear(board);
      board.squares[4][4] = const Piece(PieceType.ou, Owner.gote);
      board.squares[4][0] = const Piece(PieceType.hisha, Owner.sente);
      board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);
      // 飛車は4筋上にしか利かないため、玉は上下左右いずれかのマスへ逃げられる

      expect(board.isInCheck(Owner.gote), isTrue);
      expect(board.isCheckmate(Owner.gote), isFalse);
    });

    test('王手されていなければ合法手が少なくても詰みではない', () {
      final board = ShogiBoard();

      expect(board.isInCheck(Owner.sente), isFalse);
      expect(board.isCheckmate(Owner.sente), isFalse);
    });
  });
}
