import 'package:flutter_test/flutter_test.dart';
import 'package:itchao/data/game_web_url.dart';

void main() {
  test('rejects broken itch.io/game/:id URLs', () {
    expect(GameWebUrl.isValid('https://itch.io/game/1201843'), isFalse);
    expect(GameWebUrl.isValid('https://www.itch.io/game/1201843/'), isFalse);
  });

  test('accepts author subdomain URLs', () {
    expect(
      GameWebUrl.isValid('https://remo-wind.itch.io/attack-on-survey-corps'),
      isTrue,
    );
    expect(
      GameWebUrl.pick(
        'https://itch.io/game/1201843',
        'https://remo-wind.itch.io/attack-on-survey-corps',
      ),
      'https://remo-wind.itch.io/attack-on-survey-corps',
    );
  });
}
