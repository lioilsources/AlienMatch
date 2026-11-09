enum MirrorSide {
  left,
  right;

  bool get isLeft => this == MirrorSide.left;

  MirrorSide get toggled => isLeft ? MirrorSide.right : MirrorSide.left;

  String get label => isLeft ? 'L' : 'R';
}
