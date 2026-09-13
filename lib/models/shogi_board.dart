import 'piece.dart';

/// 盤面座標。row0=一番奥（後手側）, row8=一番手前（先手側）。
class Square {
  final int row;
  final int col;

  const Square(this.row, this.col);

  bool get onBoard => row >= 0 && row < 9 && col >= 0 && col < 9;

  @override
  bool operator ==(Object other) =>
      other is Square && other.row == row && other.col == col;

  @override
  int get hashCode => row * 9 + col;
}

/// 盤上の駒の移動、または持ち駒を打つ一手を表す。
class ShogiMove {
  final Owner owner;
  final Square? from;
  final Square to;
  final PieceType? dropType;
  final bool promote;

  ShogiMove.board(this.owner, this.from, this.to, {this.promote = false})
      : dropType = null;

  ShogiMove.drop(this.owner, PieceType type, this.to)
      : from = null,
        dropType = type,
        promote = false;

  bool get isDrop => dropType != null;
}

/// 持ち駒として打てる駒種（玉は含まない）。
const List<PieceType> _droppablePieceTypes = [
  PieceType.fu,
  PieceType.kyo,
  PieceType.kei,
  PieceType.gin,
  PieceType.kin,
  PieceType.kaku,
  PieceType.hisha,
];

/// 将棋盤の状態・持ち駒を管理し、反則手（二歩・行き所のない駒・打ち歩詰め・
/// 王手放置）を除外した合法手を計算するクラス。
class ShogiBoard {
  late List<List<Piece?>> squares;

  final Map<Owner, Map<PieceType, int>> hands = {
    Owner.sente: {for (final t in _droppablePieceTypes) t: 0},
    Owner.gote: {for (final t in _droppablePieceTypes) t: 0},
  };

  ShogiBoard() {
    squares = List.generate(9, (_) => List<Piece?>.filled(9, null));
    _setInitialPosition();
  }

  void _setInitialPosition() {
    const backRank = [
      PieceType.kyo,
      PieceType.kei,
      PieceType.gin,
      PieceType.kin,
      PieceType.ou,
      PieceType.kin,
      PieceType.gin,
      PieceType.kei,
      PieceType.kyo,
    ];

    for (var col = 0; col < 9; col++) {
      squares[0][col] = Piece(backRank[col], Owner.gote);
      squares[8][col] = Piece(backRank[col], Owner.sente);
      squares[2][col] = const Piece(PieceType.fu, Owner.gote);
      squares[6][col] = const Piece(PieceType.fu, Owner.sente);
    }

    squares[1][1] = const Piece(PieceType.hisha, Owner.gote);
    squares[1][7] = const Piece(PieceType.kaku, Owner.gote);
    squares[7][1] = const Piece(PieceType.kaku, Owner.sente);
    squares[7][7] = const Piece(PieceType.hisha, Owner.sente);
  }

  Piece? pieceAt(Square s) => squares[s.row][s.col];

  int handCount(Owner owner, PieceType type) => hands[owner]?[type] ?? 0;

  /// 持ち駒がある駒種一覧（表示用）。
  List<PieceType> handPieceTypes(Owner owner) =>
      _droppablePieceTypes.where((t) => handCount(owner, t) > 0).toList();

  /// [owner]の玉が王手されているか。
  bool isInCheck(Owner owner) => _isKingInCheckOnBoard(squares, owner);

  /// [owner]が王手された状態で、合法手が一つも残っていない（詰み）か。
  bool isCheckmate(Owner owner) => isInCheck(owner) && legalMoves(owner).isEmpty;

  /// [from]の駒が、反則手（王手放置）を除いて実際に指せる移動先。
  ///
  /// 歩・香が最奥段、桂が最奥2段に進む手も、成りによって解消されるため
  /// ここでは除外しない（[mustPromote]で強制成りとして扱う）。
  List<Square> legalDestinations(Square from) {
    final piece = pieceAt(from);
    if (piece == null) return [];
    return _rawDestinationsOnBoard(squares, from)
        .where((to) => !_wouldLeaveOwnKingInCheckAfterMove(from, to, piece.owner))
        .toList();
  }

  /// [from]から[to]への移動で、成る・成らないを選択できるか。
  bool canPromote(Square from, Square to) {
    final piece = pieceAt(from);
    if (piece == null || piece.promoted || !piece.type.canPromote) {
      return false;
    }
    return _inPromotionZone(piece.owner, from.row) ||
        _inPromotionZone(piece.owner, to.row);
  }

  /// [from]から[to]への移動で、成らないと行き所のない駒になるため
  /// 強制的に成る必要があるか。
  bool mustPromote(Square from, Square to) {
    final piece = pieceAt(from);
    if (piece == null) return false;
    return !_isValidLandingSquare(piece.type, piece.owner, to);
  }

  bool _inPromotionZone(Owner owner, int row) =>
      owner == Owner.sente ? row <= 2 : row >= 6;

  /// [owner]が持ち駒の[type]を打てるマス一覧
  /// （二歩・行き所のない駒・打ち歩詰め・王手放置を除く）。
  List<Square> legalDropSquares(Owner owner, PieceType type) {
    if (handCount(owner, type) <= 0) return [];

    final result = <Square>[];
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        final to = Square(row, col);
        if (pieceAt(to) != null) continue;
        if (!_isValidLandingSquare(type, owner, to)) continue;
        if (type == PieceType.fu && _hasUnpromotedPawnInFile(owner, col)) {
          continue; // 二歩
        }
        if (_wouldLeaveOwnKingInCheckAfterDrop(owner, type, to)) continue;
        if (type == PieceType.fu && _isUchifuzume(owner, to)) continue;
        result.add(to);
      }
    }
    return result;
  }

  /// [owner]が指せる合法手（盤上の駒の移動・持ち駒を打つ手）をすべて列挙する。
  /// 成る・成らないを選べる手は、それぞれ別の手として含まれる。
  List<ShogiMove> legalMoves(Owner owner) {
    final moves = <ShogiMove>[];

    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        final piece = squares[row][col];
        if (piece == null || piece.owner != owner) continue;
        final from = Square(row, col);
        for (final to in legalDestinations(from)) {
          if (mustPromote(from, to)) {
            moves.add(ShogiMove.board(owner, from, to, promote: true));
          } else if (canPromote(from, to)) {
            moves.add(ShogiMove.board(owner, from, to, promote: true));
            moves.add(ShogiMove.board(owner, from, to));
          } else {
            moves.add(ShogiMove.board(owner, from, to));
          }
        }
      }
    }

    for (final type in handPieceTypes(owner)) {
      for (final to in legalDropSquares(owner, type)) {
        moves.add(ShogiMove.drop(owner, type, to));
      }
    }

    return moves;
  }

  /// [legalMoves]で列挙した一手を盤面に適用する。
  void applyMove(ShogiMove move) {
    if (move.isDrop) {
      dropPiece(move.owner, move.dropType!, move.to);
    } else {
      movePiece(move.from!, move.to, promote: move.promote);
    }
  }

  /// [from]の駒を[to]へ移動する（取った駒があれば持ち駒に加える）。
  /// [promote]がtrueの場合、移動した駒を成った状態にする。
  void movePiece(Square from, Square to, {bool promote = false}) {
    final piece = squares[from.row][from.col];
    final captured = squares[to.row][to.col];
    if (piece != null && captured != null) {
      final hand = hands[piece.owner]!;
      hand[captured.type] = (hand[captured.type] ?? 0) + 1;
    }
    squares[to.row][to.col] =
        piece == null ? null : (promote ? piece.copyWith(promoted: true) : piece);
    squares[from.row][from.col] = null;
  }

  /// [owner]の持ち駒[type]を[to]に打つ。
  void dropPiece(Owner owner, PieceType type, Square to) {
    final hand = hands[owner]!;
    hand[type] = (hand[type] ?? 0) - 1;
    squares[to.row][to.col] = Piece(type, owner);
  }

  /// 歩・香が最奥段、桂が最奥2段に進む「行き所のない駒」を禁止する。
  bool _isValidLandingSquare(PieceType type, Owner owner, Square to) {
    final lastRank = owner == Owner.sente ? 0 : 8;
    final secondLastRank = owner == Owner.sente ? 1 : 7;
    switch (type) {
      case PieceType.fu:
      case PieceType.kyo:
        return to.row != lastRank;
      case PieceType.kei:
        return to.row != lastRank && to.row != secondLastRank;
      default:
        return true;
    }
  }

  bool _hasUnpromotedPawnInFile(Owner owner, int col) {
    for (var row = 0; row < 9; row++) {
      final p = squares[row][col];
      if (p != null && p.owner == owner && p.type == PieceType.fu && !p.promoted) {
        return true;
      }
    }
    return false;
  }

  bool _wouldLeaveOwnKingInCheckAfterMove(
      Square from, Square to, Owner owner) {
    final board = _cloneBoard(squares);
    board[to.row][to.col] = board[from.row][from.col];
    board[from.row][from.col] = null;
    return _isKingInCheckOnBoard(board, owner);
  }

  bool _wouldLeaveOwnKingInCheckAfterDrop(
      Owner owner, PieceType type, Square to) {
    final board = _cloneBoard(squares);
    board[to.row][to.col] = Piece(type, owner);
    return _isKingInCheckOnBoard(board, owner);
  }

  /// [owner]が[to]に歩を打つ手が打ち歩詰めかどうかを判定する。
  bool _isUchifuzume(Owner owner, Square to) {
    final board = _cloneBoard(squares);
    board[to.row][to.col] = Piece(PieceType.fu, owner);
    final opponent = owner == Owner.sente ? Owner.gote : Owner.sente;
    if (!_isKingInCheckOnBoard(board, opponent)) return false;
    return !_hasBoardMoveEscapingCheck(board, opponent);
  }

  /// 歩の直接王手は合い駒で防げないため、盤上の駒の移動（玉の移動・取り）
  /// だけで王手を逃れられるかを調べれば打ち歩詰め判定として十分。
  bool _hasBoardMoveEscapingCheck(List<List<Piece?>> board, Owner owner) {
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        final piece = board[row][col];
        if (piece == null || piece.owner != owner) continue;
        final from = Square(row, col);
        for (final to in _rawDestinationsOnBoard(board, from)) {
          final next = _cloneBoard(board);
          next[to.row][to.col] = next[from.row][from.col];
          next[from.row][from.col] = null;
          if (!_isKingInCheckOnBoard(next, owner)) return true;
        }
      }
    }
    return false;
  }

  bool _isKingInCheckOnBoard(List<List<Piece?>> board, Owner owner) {
    Square? kingSquare;
    for (var row = 0; row < 9 && kingSquare == null; row++) {
      for (var col = 0; col < 9; col++) {
        final p = board[row][col];
        if (p != null && p.owner == owner && p.type == PieceType.ou) {
          kingSquare = Square(row, col);
          break;
        }
      }
    }
    if (kingSquare == null) return false;

    final enemy = owner == Owner.sente ? Owner.gote : Owner.sente;
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        final p = board[row][col];
        if (p == null || p.owner != enemy) continue;
        if (_rawDestinationsOnBoard(board, Square(row, col))
            .contains(kingSquare)) {
          return true;
        }
      }
    }
    return false;
  }

  List<List<Piece?>> _cloneBoard(List<List<Piece?>> board) => [
        for (final row in board) List<Piece?>.from(row),
      ];

  /// 駒種ごとの基本的な移動先（反則手判定を含まない）を[board]上で計算する。
  List<Square> _rawDestinationsOnBoard(List<List<Piece?>> board, Square from) {
    final piece = board[from.row][from.col];
    if (piece == null) return [];

    final forward = piece.owner == Owner.sente ? -1 : 1;
    final destinations = <Square>[];

    void addStep(int dRow, int dCol) {
      final to = Square(from.row + dRow, from.col + dCol);
      if (!to.onBoard) return;
      final target = board[to.row][to.col];
      if (target == null || target.owner != piece.owner) {
        destinations.add(to);
      }
    }

    void addSlide(int dRow, int dCol) {
      var to = Square(from.row + dRow, from.col + dCol);
      while (to.onBoard) {
        final target = board[to.row][to.col];
        if (target == null) {
          destinations.add(to);
        } else {
          if (target.owner != piece.owner) destinations.add(to);
          break;
        }
        to = Square(to.row + dRow, to.col + dCol);
      }
    }

    void addGoldSteps() {
      for (final step in [
        [forward, 0],
        [forward, -1],
        [forward, 1],
        [0, -1],
        [0, 1],
        [-forward, 0],
      ]) {
        addStep(step[0], step[1]);
      }
    }

    if (piece.promoted) {
      // と・成香・成桂・成銀は金と同じ動き、馬・龍はそれぞれ角・飛に
      // 玉と同じ4方向の一マス移動を加えた動き。
      switch (piece.type) {
        case PieceType.fu:
        case PieceType.kyo:
        case PieceType.kei:
        case PieceType.gin:
          addGoldSteps();
          break;
        case PieceType.kaku:
          addSlide(-1, -1);
          addSlide(-1, 1);
          addSlide(1, -1);
          addSlide(1, 1);
          addStep(-1, 0);
          addStep(1, 0);
          addStep(0, -1);
          addStep(0, 1);
          break;
        case PieceType.hisha:
          addSlide(-1, 0);
          addSlide(1, 0);
          addSlide(0, -1);
          addSlide(0, 1);
          addStep(-1, -1);
          addStep(-1, 1);
          addStep(1, -1);
          addStep(1, 1);
          break;
        case PieceType.kin:
        case PieceType.ou:
          break; // 金・玉は成れないため到達しない
      }
      return destinations;
    }

    switch (piece.type) {
      case PieceType.fu:
        addStep(forward, 0);
        break;
      case PieceType.kyo:
        addSlide(forward, 0);
        break;
      case PieceType.kei:
        addStep(forward * 2, -1);
        addStep(forward * 2, 1);
        break;
      case PieceType.gin:
        addStep(forward, 0);
        addStep(forward, -1);
        addStep(forward, 1);
        addStep(-forward, -1);
        addStep(-forward, 1);
        break;
      case PieceType.kin:
        addGoldSteps();
        break;
      case PieceType.ou:
        for (final step in [
          [-1, -1],
          [-1, 0],
          [-1, 1],
          [0, -1],
          [0, 1],
          [1, -1],
          [1, 0],
          [1, 1],
        ]) {
          addStep(step[0], step[1]);
        }
        break;
      case PieceType.kaku:
        addSlide(-1, -1);
        addSlide(-1, 1);
        addSlide(1, -1);
        addSlide(1, 1);
        break;
      case PieceType.hisha:
        addSlide(-1, 0);
        addSlide(1, 0);
        addSlide(0, -1);
        addSlide(0, 1);
        break;
    }

    return destinations;
  }
}
