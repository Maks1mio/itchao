import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itchao/data/game_page_parser.dart';

void main() {
  test('parses Attack on Survey Corps sample', () {
    final html = File('Sites/Attack on Survey Corps [FREE VERSION] by Remo_Wind.html')
        .readAsStringSync();
    final detail = const ItchGamePageParser().parse(
      html,
      webUrl: 'https://remo-wind.itch.io/attack-on-survey-corps',
    );

    expect(detail.id, 1201843);
    expect(detail.title, contains('Attack on Survey Corps'));
    expect(detail.developerName, 'Remo_Wind');
    expect(detail.screenshots.length, greaterThan(3));
    expect(detail.ratingAverage, closeTo(4.6, 0.1));
    expect(detail.ratingCount, greaterThan(1000));
    expect(detail.iconUrl, isNotNull);
    expect(detail.infoRows['Обновлено'], isNotNull);
  });

  test('parses Gamer Struggles description HTML and banner', () {
    final html = File('Sites/Gamer Struggles (NSFW) by Cumbusters.html').readAsStringSync();
    final detail = const ItchGamePageParser().parse(
      html,
      webUrl: 'https://cumbusters.itch.io/gamerstruggles',
    );

    expect(detail.descriptionHtml.length, greaterThan(200));
    expect(detail.descriptionHtml, contains('iframe'));
    expect(
      detail.descriptionHtml.contains('img.itch.zone') ||
          detail.descriptionHtml.contains('patreon.com'),
      isTrue,
    );
    expect(detail.description.length, greaterThan(20));
    expect(detail.headerCoverUrl == null || detail.headerCoverUrl!.contains('itch.zone'), isTrue);
    expect(detail.theme?.backgroundImageUrl, contains('Q%2FA3ru'));
    expect(detail.theme?.backgroundColor, const Color(0xFF163B3E));
    expect(detail.descriptionHtml, contains('KyK8hS'));
    expect(detail.descriptionHtml, contains('itch.io/embed/2746711'));
    expect(detail.infoRows['Обновлено'], '27 days ago');
  });
}
