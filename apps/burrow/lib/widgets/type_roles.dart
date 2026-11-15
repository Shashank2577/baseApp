import 'package:base_core/base_core.dart';
import 'package:flutter/material.dart';

// Stand-ins for the type roles and the content row in design/REVIEW.md 2.4
// and 2.5 (contentTitle, rowTitle, reading, caption, ItemRow). They are built
// only from base_design's tokens and colours; once base_design ships the
// roles, Burrow uses those and this file goes.

/// The title of a talk or a person on its own page: data, so the reading face.
TextStyle contentTitle(BuildContext context) => context.type.bodyStyle(22, 28, weight: 600);

/// The title of a content row (a talk, a person).
TextStyle rowTitle(BuildContext context) => context.type.bodyStyle(17, 24, weight: 600);

/// Summaries, transcripts and answers.
TextStyle reading(BuildContext context) => context.type.bodyStyle(17, 26);

/// Timestamps, counts, sizes.
TextStyle caption(BuildContext context) => context.type.bodyStyle(13, 18, color: context.colors.pencil);

/// A row for content (a talk, a person, a voice): its title in the reading
/// face, a meta line, and a plain arrow when it opens something.
class ContentRow extends StatelessWidget {
  const ContentRow(this.title, {super.key, this.meta, this.onTap, this.leading, this.alert = false, this.selected = false});
  final String title;
  final String? meta;
  final VoidCallback? onTap;
  final Widget? leading;
  final bool alert;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            color: selected ? c.smudge : null,
            border: selected ? Border(left: BorderSide(color: c.ink, width: 3)) : null,
          ),
          padding: EdgeInsets.fromLTRB(selected ? 9 : 0, 12, 0, 12),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: rowTitle(context))),
                        if (alert) ...[
                          const SizedBox(width: 4),
                          DoodleIcon(Doodle.exclaim, size: 18, color: c.redPen, semanticLabel: 'needs a look'),
                        ],
                      ],
                    ),
                    if (meta != null) ...[const SizedBox(height: 2), Meta(meta!, maxLines: 2)],
                  ],
                ),
              ),
              if (onTap != null) ...[const SizedBox(width: 12), DoodleIcon(Doodle.arrow, size: 20, color: c.pencil)],
            ],
          ),
        ),
      ),
    );
  }
}
