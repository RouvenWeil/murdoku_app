import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design/murdoku_typography.dart';

// Header lockup shared between the catalogue and case view
class MurdokuBrand extends StatelessWidget {
  const MurdokuBrand({super.key, this.logoHeight = 32});

  final double logoHeight;

  @override
  Widget build(BuildContext context) {
    final typography = MurdokuTypography.forViewport(
      MediaQuery.sizeOf(context).width,
    );
    return Semantics(
      label: 'Murdoku by Manuel Garand',
      child: ExcludeSemantics(
        child: FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsetsGeometry.fromLTRB(0, 8, 0, 0),
                child: SvgPicture.asset(
                  'assets/ui/Murdoku-Logo.svg',
                  height: logoHeight,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'by Manuel Garand',
                maxLines: 1,
                style: typography.logoAddon,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
