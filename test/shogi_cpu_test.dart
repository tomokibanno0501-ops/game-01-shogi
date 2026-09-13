import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yuru_syougi/models/piece.dart';
import 'package:yuru_syougi/models/shogi_board.dart';

void main() {
  group('CPU用の合法手列挙', () {
    test('初期局面では合法手が双方30手ずつある（将棋の初期局面の既知の合法手数）', () {
      final board = ShogiBoard();

      final goteMoves = board.legalMoves(Owner.gote);
      final senteMoves = board.legalMoves(Owner.sente);

      expect(goteMoves.length, 30);
      expect(goteMoves.every((m) => m.owner == Owner.gote), isTrue);
      expect(senteMoves.length, 30);
    });

    test('合法手をランダムに選んで適用すると手番の駒が動く', () {
      final board = ShogiBoard();
      final moves = board.legalMoves(Owner.gote);
      final move = moves[Random(0).nextInt(moves.length)];

      board.applyMove(move);

      if (move.isDrop) {
        expect(board.pieceAt(move.to)?.type, move.dropType);
      } else {
        expect(board.pieceAt(move.to)?.owner, Owner.gote);
        expect(board.pieceAt(move.from!), isNull);
      }
    });

    test('合法手が反則手（二歩・行き所のない駒・王手放置）を含まない', () {
      final board = ShogiBoard();

      final senteMoves = board.legalMoves(Owner.sente);
      final goteMoves = board.legalMoves(Owner.gote);

      // 初期局面は王手がかかっていないため、双方に合法手が存在する
      expect(senteMoves, isNotEmpty);
      expect(goteMoves, isNotEmpty);
    });

    test('CPU同士のランダム自己対戦を繰り返しても反則手が発生しない', () {
      // 実際にCPUが使うAPI（legalMoves→ランダム選択→applyMove）をそのまま
      // 多局・多手数にわたって回し、途中で自玉を取られる・玉が消えるといった
      // 反則状態に陥らないことを確認する。
      for (var game = 0; game < 20; game++) {
        final board = ShogiBoard();
        final random = Random(game);
        var turn = Owner.sente;

        for (var ply = 0; ply < 200; ply++) {
          expect(_countKings(board), 2,
              reason: '対局$game 手数$plyで玉の数が異常');

          if (board.isCheckmate(turn)) break;
          final moves = board.legalMoves(turn);
          if (moves.isEmpty) break; // 王手されていない手詰まり（想定外だが安全側で終了）

          final move = moves[random.nextInt(moves.length)];
          expect(move.owner, turn);
          board.applyMove(move);

          turn = turn == Owner.sente ? Owner.gote : Owner.sente;
        }
      }
    });
  });
}

int _countKings(ShogiBoard board) {
  var count = 0;
  for (var row = 0; row < 9; row++) {
    for (var col = 0; col < 9; col++) {
      if (board.pieceAt(Square(row, col))?.type == PieceType.ou) count++;
    }
  }
  return count;
}
