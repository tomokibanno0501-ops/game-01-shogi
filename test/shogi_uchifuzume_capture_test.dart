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

/// 3テスト共通の土台となる盤面を用意する。
///
/// 後手玉(0,0)は、自分の香(0,1)・桂(1,1)に囲まれており、
/// (0,1)(1,1)には自力で移動できない（行き場がない）。
/// 残る逃げ場・反撃手段は「歩を打たれるマス(1,0)」だけになる。
ShogiBoard _buildBaseBoard() {
  final board = ShogiBoard();
  _clear(board);
  board.squares[0][0] = const Piece(PieceType.ou, Owner.gote);
  board.squares[0][1] = const Piece(PieceType.kyo, Owner.gote);
  board.squares[1][1] = const Piece(PieceType.kei, Owner.gote);
  board.squares[8][8] = const Piece(PieceType.ou, Owner.sente);
  board.hands[Owner.sente]![PieceType.fu] = 1;
  return board;
}

void main() {
  group('打ち歩詰め: 玉以外の駒による捕獲の扱い', () {
    test(
        '1. 玉自身は逃げられないが、玉以外の駒（銀）が打たれた歩を取れる場合は'
        '打ち歩詰めではなく合法', () {
      final board = _buildBaseBoard();
      // 打たれた歩(1,0)を斜め後ろに取れる銀を配置する。
      board.squares[2][1] = const Piece(PieceType.gin, Owner.gote);
      // 玉自身の取り返しは、香(8,0)の利きが(1,0)に通っているため王手放置となり不可。
      board.squares[8][0] = const Piece(PieceType.kyo, Owner.sente);

      final drops = board.legalDropSquares(Owner.sente, PieceType.fu);

      expect(drops.contains(const Square(1, 0)), isTrue,
          reason: '銀が歩を取り返せるため打ち歩詰めにはならないはず');
    });

    test('2. 玉自身も玉以外の駒も打たれた歩を取れない場合は打ち歩詰めとして反則', () {
      final board = _buildBaseBoard();
      // 玉以外に歩を取り返せる駒は置かない。
      // 玉自身の取り返しも、香(8,0)の利きにより王手放置となり不可。
      board.squares[8][0] = const Piece(PieceType.kyo, Owner.sente);

      final drops = board.legalDropSquares(Owner.sente, PieceType.fu);

      expect(drops.contains(const Square(1, 0)), isFalse,
          reason: '玉も他の駒も歩を取り返せず、逃げ場もないため真の打ち歩詰めのはず');
    });

    test('3. 玉自身が安全に歩を取れる場合（他の駒に頼らない経路）も合法と判定される', () {
      final board = _buildBaseBoard();
      // 玉以外の捕獲駒は置かず、(1,0)を守る駒も置かない
      // →玉自身がそのまま安全に取り返せる。

      final drops = board.legalDropSquares(Owner.sente, PieceType.fu);

      expect(drops.contains(const Square(1, 0)), isTrue,
          reason: '玉自身が安全に歩を取り返せるため打ち歩詰めにはならないはず');
    });
  });
}
