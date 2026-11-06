import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/ui/screens/case_screen.dart';
import 'package:murdoku_app/ui/widgets/tool_panel_stub.dart';

void main() {
  group('Board-first layout geometry', () {
    test('small landscape displays five complete cells per axis', () {
      final layout = CaseScreenLayout.calculate(
        availableSize: const Size(720, 272),
        rows: 16,
        columns: 16,
      )!;

      expect(layout.isPartial, isTrue);
      expect(layout.visibleRows, 5);
      expect(layout.visibleColumns, 5);
      expect(layout.cellSize, closeTo(51.2, 0.00001));
      expect(layout.boardRegionWidth, 256);
      expect(layout.boardRegionHeight, 256);
      expect(layout.toolWidth, greaterThanOrEqualTo(176));
      expect(layout.toolArrangement, ToolPanelArrangement.horizontal);
      expect(layout.minimapSize, greaterThanOrEqualTo(96));
      expect(layout.clueWidth, greaterThanOrEqualTo(220));
    });

    test('full board uses natural rectangular aspect ratio', () {
      final layout = CaseScreenLayout.calculate(
        availableSize: const Size(1000, 600),
        rows: 10,
        columns: 9,
      )!;

      expect(layout.isPartial, isFalse);
      expect(layout.visibleRows, 10);
      expect(layout.visibleColumns, 9);
      expect(
        layout.boardRegionHeight / layout.boardRegionWidth,
        closeTo(10 / 9, 0.00001),
      );
      expect(layout.minimapSize, 0);
      expect(layout.toolWidth, greaterThanOrEqualTo(112));
    });

    test('a large board can fit completely without showing the minimap', () {
      final layout = CaseScreenLayout.calculate(
        availableSize: const Size(1400, 850),
        rows: 16,
        columns: 16,
      )!;

      expect(layout.isPartial, isFalse);
      expect(layout.visibleRows, 16);
      expect(layout.visibleColumns, 16);
      expect(layout.cellSize, greaterThanOrEqualTo(48));
      expect(layout.minimapSize, 0);
    });

    test('a six-by-six board can require partial mode on a small display', () {
      final layout = CaseScreenLayout.calculate(
        availableSize: const Size(720, 272),
        rows: 6,
        columns: 6,
      )!;

      expect(layout.isPartial, isTrue);
      expect(layout.visibleRows, 5);
      expect(layout.toolWidth, greaterThanOrEqualTo(176));
      expect(layout.toolArrangement, ToolPanelArrangement.horizontal);
    });

    test('a full six-by-six board fits at precisely 48dp per cell', () {
      final layout = CaseScreenLayout.calculate(
        availableSize: const Size(638, 304),
        rows: 6,
        columns: 6,
      )!;

      expect(layout.isPartial, isFalse);
      expect(layout.cellSize, 48);
      expect(layout.boardRegionWidth, 288);
      expect(layout.boardRegionHeight, 288);
    });

    test(
      'dropping below the full-fit threshold switches tool configuration',
      () {
        final layout = CaseScreenLayout.calculate(
          availableSize: const Size(638, 303.9),
          rows: 6,
          columns: 6,
        )!;

        expect(layout.isPartial, isTrue);
        expect(layout.visibleRows, 5);
        expect(layout.visibleColumns, 5);
        expect(layout.toolArrangement, ToolPanelArrangement.stacked);
        expect(layout.toolWidth, greaterThanOrEqualTo(120));
        expect(layout.cellSize, greaterThanOrEqualTo(48));
      },
    );

    test('rectangular boards use square partial regions', () {
      final layout = CaseScreenLayout.calculate(
        availableSize: const Size(800, 312),
        rows: 10,
        columns: 9,
      )!;

      expect(layout.isPartial, isTrue);
      expect(layout.visibleRows, layout.visibleColumns);
      expect(layout.boardRegionWidth, layout.boardRegionHeight);
    });

    test('224dp is the exact minimum height for horizontal compact tools', () {
      final layout = CaseScreenLayout.calculate(
        availableSize: const Size(600, 224),
        rows: 16,
        columns: 16,
      )!;

      expect(layout.isPartial, isTrue);
      expect(layout.minimapSize, 96);
      expect(layout.toolArrangement, ToolPanelArrangement.horizontal);
      expect(layout.cellSize, greaterThanOrEqualTo(48));
    });

    test('height too short for all partial controls has no viable layout', () {
      expect(
        CaseScreenLayout.calculate(
          availableSize: const Size(600, 223.9),
          rows: 16,
          columns: 16,
        ),
        isNull,
      );
    });

    test('width too small for all three regions has no viable layout', () {
      expect(
        CaseScreenLayout.calculate(
          availableSize: const Size(461.9, 224),
          rows: 16,
          columns: 16,
        ),
        isNull,
      );
    });

    test('the narrowest mathematically viable layout shows one full cell', () {
      final layout = CaseScreenLayout.calculate(
        availableSize: const Size(462, 224),
        rows: 16,
        columns: 16,
      )!;

      // The minimum useful number of visible cells is not yet agreed
      expect(layout.isPartial, isTrue);
      expect(layout.visibleRows, 1);
      expect(layout.visibleColumns, 1);
      expect(layout.cellSize, 48);
    });

    test('narrow landscape selects two icon buttons plus a text button', () {
      final layout = CaseScreenLayout.calculate(
        availableSize: const Size(560, 300),
        rows: 16,
        columns: 16,
      )!;

      expect(layout.toolArrangement, ToolPanelArrangement.stacked);
      expect(layout.visibleRows, 4);
      expect(layout.visibleColumns, 4);
      expect(layout.minimapSize, greaterThanOrEqualTo(96));
      expect(layout.toolWidth, greaterThanOrEqualTo(120));
      expect(layout.cellSize, greaterThanOrEqualTo(48));
    });

    test('tall enough landscape selects one column of four text buttons', () {
      final layout = CaseScreenLayout.calculate(
        availableSize: const Size(560, 336),
        rows: 16,
        columns: 16,
      )!;

      expect(layout.toolArrangement, ToolPanelArrangement.singleColumn);
      expect(layout.visibleRows, 4);
      expect(layout.visibleColumns, 4);
      expect(layout.cellSize, closeTo(52.5, 0.00001));
      expect(layout.toolWidth, greaterThanOrEqualTo(112));
      expect(layout.minimapSize, greaterThanOrEqualTo(96));
    });

    test('single-column arrangement requires all 336dp of height', () {
      final layout = CaseScreenLayout.calculate(
        availableSize: const Size(560, 335.9),
        rows: 16,
        columns: 16,
      )!;
      expect(layout.toolArrangement, ToolPanelArrangement.stacked);
    });

    test('96dp minimap minimum rejects inadequate compact tool height', () {
      expect(
        CaseScreenLayout.calculate(
          availableSize: const Size(720, 223.9),
          rows: 16,
          columns: 16,
        ),
        isNull,
      );
    });

    test('minimap preserves a rectangular board aspect ratio', () {
      final layout = CaseScreenLayout.calculate(
        availableSize: const Size(640, 336),
        rows: 10,
        columns: 9,
      )!;

      expect(layout.isPartial, isTrue);
      expect(
        layout.minimapWidth / layout.minimapHeight,
        closeTo(9 / 10, 0.00001),
      );
      expect(layout.minimapSize, greaterThanOrEqualTo(96));
      expect(
        layout.minimapWidth,
        lessThanOrEqualTo(layout.toolWidth - 16 + 0.000001),
      );
    });

    test(
      'wide boards reserve enough minimap width before sizing the board',
      () {
        final layout = CaseScreenLayout.calculate(
          availableSize: const Size(900, 360),
          rows: 9,
          columns: 16,
        )!;

        expect(layout.isPartial, isTrue);
        expect(
          layout.minimapWidth / layout.minimapHeight,
          closeTo(16 / 9, 0.00001),
        );
        expect(layout.minimapSize, greaterThanOrEqualTo(96));
        expect(layout.toolWidth, greaterThanOrEqualTo(96 * 16 / 9 + 16));
        expect(
          layout.minimapWidth,
          lessThanOrEqualTo(layout.toolWidth - 16 + 0.000001),
        );
      },
    );

    test('smallest 96dp minimap requires at least 112dp panel width', () {
      final layout = CaseScreenLayout.calculate(
        availableSize: const Size(398, 336),
        rows: 16,
        columns: 16,
      )!;

      expect(layout.toolArrangement, ToolPanelArrangement.singleColumn);
      expect(layout.toolWidth, 112);
      expect(layout.visibleRows, 1);
      expect(layout.cellSize, 48);
      expect(layout.minimapSize, 96);
    });

    test(
      'invalid dimensions and unbounded viewports are handled explicitly',
      () {
        expect(
          () => CaseScreenLayout.calculate(
            availableSize: const Size(720, 320),
            rows: 0,
            columns: 6,
          ),
          throwsArgumentError,
        );
        expect(
          CaseScreenLayout.calculate(
            availableSize: const Size(double.infinity, 320),
            rows: 6,
            columns: 6,
          ),
          isNull,
        );
      },
    );

    test(
      'all reference displays preserve minimum dimensions and total width',
      () {
        const screens = [
          Size(720, 272),
          Size(800, 312),
          Size(844, 342),
          Size(896, 366),
        ];
        for (final screen in screens) {
          for (final dimensions in [(6, 6), (10, 9), (16, 16)]) {
            final layout = CaseScreenLayout.calculate(
              availableSize: screen,
              rows: dimensions.$1,
              columns: dimensions.$2,
            )!;

            expect(layout.cellSize, greaterThanOrEqualTo(48));
            expect(layout.clueWidth, greaterThanOrEqualTo(220));
            expect(
              layout.toolWidth,
              greaterThanOrEqualTo(layout.isPartial ? 112 : 112),
            );
            expect(
              layout.boardViewportWidth,
              greaterThanOrEqualTo(layout.boardRegionWidth + 16 - 0.000001),
            );
            expect(
              layout.boardRegionHeight + 16,
              lessThanOrEqualTo(screen.height + 0.000001),
            );
            expect(
              layout.clueWidth +
                  layout.boardViewportWidth +
                  layout.toolWidth +
                  2,
              closeTo(screen.width, 0.000001),
            );
            if (layout.isPartial) {
              expect(layout.visibleRows, layout.visibleColumns);
              expect(layout.minimapSize, greaterThanOrEqualTo(96));
              expect(
                layout.minimapWidth,
                lessThanOrEqualTo(layout.toolWidth - 16 + 0.000001),
              );
              final rows = switch (layout.toolArrangement) {
                ToolPanelArrangement.horizontal => 2,
                ToolPanelArrangement.stacked => 3,
                ToolPanelArrangement.singleColumn => 4,
                ToolPanelArrangement.expanded => throw StateError(
                  'Unexpected expanded tools',
                ),
              };
              expect(
                layout.minimapHeight + 16 + rows * 56,
                lessThanOrEqualTo(screen.height + 0.000001),
              );
            } else {
              expect(layout.visibleRows, dimensions.$1);
              expect(layout.visibleColumns, dimensions.$2);
              expect(layout.minimapSize, 0);
            }
          }
        }
      },
    );
  });
}
