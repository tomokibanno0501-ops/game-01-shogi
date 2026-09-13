import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/piece.dart';
import '../models/shogi_board.dart';

/// 人間が操作する側。CPU（ランダムAI）はこの反対側を指す。
const _humanOwner = Owner.sente;

/// 人間の手が終わってからCPUが指すまでの間。
const _cpuThinkingDelay = Duration(milliseconds: 700);

/// 駒を動かす・打つたびに再生する効果音のアセットパス。
const _moveSoundAsset = 'sounds/piece_move.wav';

const _boardColor = Color(0xFFDEB887);
const _lineColor = Color(0xFF5D4037);
const _highlightColor = Color(0x8865B96D);
const _selectedColor = Color(0x88FFC107);
const _senteColor = Color(0xFF1A1A1A);
const _goteColor = Color(0xFFB71C1C);

class ShogiBoardWidget extends StatefulWidget {
  const ShogiBoardWidget({super.key});

  @override
  State<ShogiBoardWidget> createState() => _ShogiBoardWidgetState();
}

class _ShogiBoardWidgetState extends State<ShogiBoardWidget> {
  ShogiBoard _board = ShogiBoard();
  Owner _currentTurn = Owner.sente;
  Square? _selected;
  PieceType? _selectedHandType;
  List<Square> _highlighted = [];
  Owner? _winner;
  String? _resultReason;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Owner get _opponent => _currentTurn == Owner.sente ? Owner.gote : Owner.sente;

  Owner _other(Owner owner) => owner == Owner.sente ? Owner.gote : Owner.sente;

  String get _statusText {
    final winner = _winner;
    if (winner != null) {
      return '${winner == Owner.sente ? "先手" : "後手"}の勝ち（$_resultReason）';
    }
    return _currentTurn == Owner.sente ? '先手番' : '後手番';
  }

  Future<void> _onSquareTap(Square square) async {
    if (_winner != null) return; // 対局終了後は操作不可
    if (_currentTurn != _humanOwner) return; // CPUの手番中は操作不可

    if (_selectedHandType != null) {
      if (_highlighted.contains(square)) {
        setState(() {
          _board.dropPiece(_currentTurn, _selectedHandType!, square);
          _selectedHandType = null;
          _highlighted = [];
          _currentTurn = _opponent;
          _updateGameEndState();
        });
        _playMoveSound();
        _afterMove();
      } else {
        setState(() {
          _selectedHandType = null;
          _highlighted = [];
        });
      }
      return;
    }

    final tappedPiece = _board.pieceAt(square);

    if (_selected != null && _highlighted.contains(square)) {
      final from = _selected!;
      var promote = false;
      if (_board.mustPromote(from, square)) {
        promote = true;
      } else if (_board.canPromote(from, square)) {
        promote = await _askPromote() ?? false;
        if (!mounted) return;
      }
      setState(() {
        _board.movePiece(from, square, promote: promote);
        _selected = null;
        _highlighted = [];
        _currentTurn = _opponent;
        _updateGameEndState();
      });
      _playMoveSound();
      _afterMove();
      return;
    }

    if (tappedPiece != null && tappedPiece.owner == _currentTurn) {
      setState(() {
        _selected = square;
        _highlighted = _board.legalDestinations(square);
      });
      return;
    }

    setState(() {
      _selected = null;
      _highlighted = [];
    });
  }

  void _afterMove() {
    if (_winner != null) {
      _showResultDialog();
      return;
    }
    _scheduleCpuTurnIfNeeded();
  }

  void _scheduleCpuTurnIfNeeded() {
    if (_winner != null || _currentTurn == _humanOwner) return;
    Future.delayed(_cpuThinkingDelay, _playCpuMove);
  }

  void _playCpuMove() {
    if (!mounted || _winner != null || _currentTurn == _humanOwner) return;
    final cpuOwner = _currentTurn;
    final moves = _board.legalMoves(cpuOwner);
    if (moves.isEmpty) return; // 王手されていない状況での手詰まりは想定外

    final move = moves[Random().nextInt(moves.length)];
    setState(() {
      _board.applyMove(move);
      _currentTurn = _opponent;
      _updateGameEndState();
    });
    _playMoveSound();
    _afterMove();
  }

  /// 駒を動かす・打つたびに鳴らす効果音。
  void _playMoveSound() {
    _audioPlayer.play(AssetSource(_moveSoundAsset));
  }

  /// 現在手番の[_currentTurn]が詰みかどうかを判定し、詰みなら勝敗を確定する。
  void _updateGameEndState() {
    if (_board.isCheckmate(_currentTurn)) {
      _winner = _opponent;
      _resultReason = '詰み';
    }
  }

  void _resign() {
    if (_winner != null) return;
    setState(() {
      _winner = _other(_humanOwner);
      _resultReason = '投了';
    });
    _showResultDialog();
  }

  void _showResultDialog() {
    final winner = _winner;
    if (winner == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('対局終了'),
        content: Text(
          '${winner == Owner.sente ? "先手" : "後手"}の勝ち（$_resultReason）',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startNewGame();
            },
            child: const Text('新規対局'),
          ),
        ],
      ),
    );
  }

  /// 対局を初期状態からやり直す。
  void _startNewGame() {
    setState(() {
      _board = ShogiBoard();
      _currentTurn = Owner.sente;
      _selected = null;
      _selectedHandType = null;
      _highlighted = [];
      _winner = null;
      _resultReason = null;
    });
  }

  Future<bool?> _askPromote() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('成りますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('成らない'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('成る'),
          ),
        ],
      ),
    );
  }

  void _onHandTap(Owner owner, PieceType type) {
    if (_winner != null || _currentTurn != _humanOwner || owner != _currentTurn) {
      return;
    }
    setState(() {
      _selected = null;
      if (_selectedHandType == type) {
        _selectedHandType = null;
        _highlighted = [];
      } else {
        _selectedHandType = type;
        _highlighted = _board.legalDropSquares(owner, type);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const turnLabelHeight = 40.0;
        const handRowHeight = 48.0;
        final rawBoardSize = [
          constraints.maxWidth,
          constraints.maxHeight - turnLabelHeight - handRowHeight * 2,
        ].reduce((a, b) => a < b ? a : b);
        final boardSize = rawBoardSize < 0 ? 0.0 : rawBoardSize;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: turnLabelHeight,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Center(
                      child: Text(
                        _statusText,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _winner == null ? _resign : _startNewGame,
                    child: Text(_winner == null ? '投了' : '新規対局'),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: boardSize,
              height: handRowHeight,
              child: _buildHandRow(Owner.gote, rotated: true),
            ),
            SizedBox(
              width: boardSize,
              height: boardSize,
              child: Container(
                decoration: BoxDecoration(
                  color: _boardColor,
                  border: Border.all(color: _lineColor, width: 2),
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 9,
                  ),
                  itemCount: 81,
                  itemBuilder: (context, index) {
                    final row = index ~/ 9;
                    final col = index % 9;
                    final square = Square(row, col);
                    return _buildSquare(square);
                  },
                ),
              ),
            ),
            SizedBox(
              width: boardSize,
              height: handRowHeight,
              child: _buildHandRow(Owner.sente, rotated: false),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSquare(Square square) {
    final piece = _board.pieceAt(square);
    final isSelected = square == _selected;
    final isHighlighted = _highlighted.contains(square);

    return GestureDetector(
      onTap: () => _onSquareTap(square),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _lineColor, width: 0.5),
          color: isSelected
              ? _selectedColor
              : (isHighlighted ? _highlightColor : Colors.transparent),
        ),
        alignment: Alignment.center,
        child: piece == null ? null : _buildPiece(piece),
      ),
    );
  }

  Widget _buildHandRow(Owner owner, {required bool rotated}) {
    final types = _board.handPieceTypes(owner);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final type in types)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildHandPiece(owner, type, rotated: rotated),
          ),
      ],
    );
  }

  Widget _buildHandPiece(Owner owner, PieceType type, {required bool rotated}) {
    final count = _board.handCount(owner, type);
    final isSelected = _selectedHandType == type && _currentTurn == owner;
    final isGote = owner == Owner.gote;

    return GestureDetector(
      onTap: () => _onHandTap(owner, type),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? _selectedColor : _boardColor,
          border: Border.all(color: _lineColor),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Transform.rotate(
          angle: rotated ? 3.14159265 : 0,
          child: Text(
            count > 1 ? '${type.kanji(owner)}×$count' : type.kanji(owner),
            style: TextStyle(
              color: isGote ? _goteColor : _senteColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPiece(Piece piece) {
    final isGote = piece.owner == Owner.gote;
    return Transform.rotate(
      angle: isGote ? 3.14159265 : 0,
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Text(
            piece.displayKanji,
            style: TextStyle(
              color: isGote ? _goteColor : _senteColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
