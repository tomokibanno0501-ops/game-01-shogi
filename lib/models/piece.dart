/// 駒の所有者（先手・後手）
enum Owner { sente, gote }

/// 駒の種類
enum PieceType { fu, kyo, kei, gin, kin, kaku, hisha, ou }

extension PieceTypeLabel on PieceType {
  /// 盤面表示用の漢字表記（不成の状態）
  String kanji(Owner owner) {
    switch (this) {
      case PieceType.fu:
        return '歩';
      case PieceType.kyo:
        return '香';
      case PieceType.kei:
        return '桂';
      case PieceType.gin:
        return '銀';
      case PieceType.kin:
        return '金';
      case PieceType.kaku:
        return '角';
      case PieceType.hisha:
        return '飛';
      case PieceType.ou:
        return owner == Owner.sente ? '玉' : '王';
    }
  }

  /// 成った状態の漢字表記。金・玉は成れないため呼び出されない想定。
  String get promotedKanji {
    switch (this) {
      case PieceType.fu:
        return 'と';
      case PieceType.kyo:
        return '杏';
      case PieceType.kei:
        return '圭';
      case PieceType.gin:
        return '全';
      case PieceType.kaku:
        return '馬';
      case PieceType.hisha:
        return '龍';
      case PieceType.kin:
      case PieceType.ou:
        return kanji(Owner.sente);
    }
  }

  /// 成ることができる駒種か（金・玉は不可）。
  bool get canPromote =>
      this != PieceType.kin && this != PieceType.ou;
}

class Piece {
  final PieceType type;
  final Owner owner;
  final bool promoted;

  const Piece(this.type, this.owner, {this.promoted = false});

  /// 成り状態を考慮した盤面表示用の漢字表記。
  String get displayKanji => promoted ? type.promotedKanji : type.kanji(owner);

  Piece copyWith({bool? promoted}) =>
      Piece(type, owner, promoted: promoted ?? this.promoted);
}
