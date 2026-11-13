import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

import '../../../core/legal_links.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';

class AuthLegalNotice extends StatelessWidget {
  const AuthLegalNotice({super.key});

  static final _links = RegExp(r'\{termsOfUse\}|\{privacyPolicy\}');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Keep sentence order and punctuation under the translator's control.
    final notice = l.authLegalNotice('{termsOfUse}', '{privacyPolicy}');
    return LayoutBuilder(
      builder: (context, constraints) {
        final spans = <InlineSpan>[];
        var offset = 0;
        for (final match in _links.allMatches(notice)) {
          spans.add(TextSpan(text: notice.substring(offset, match.start)));
          final terms = match.group(0) == '{termsOfUse}';
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: Link(
                  uri: terms ? LegalLinks.termsOfUse : LegalLinks.privacyPolicy,
                  target: LinkTarget.blank,
                  builder: (context, followLink) => MergeSemantics(
                    key: Key(terms ? 'auth-terms-of-use' : 'auth-privacy-policy'),
                    child: Semantics(
                      link: true,
                      child: TextButton(
                        onPressed: followLink,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.authSecondary,
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.standard,
                          textStyle: AuthTypography.caption.copyWith(fontWeight: FontWeight.w700),
                        ),
                        child: Text(
                          terms ? l.authTermsOfUse : l.authPrivacyPolicy,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          offset = match.end;
        }
        spans.add(TextSpan(text: notice.substring(offset)));
        return Text.rich(
          TextSpan(children: spans),
          textAlign: TextAlign.center,
          style: AuthTypography.caption,
        );
      },
    );
  }
}
