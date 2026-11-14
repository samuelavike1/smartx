import 'package:flutter/foundation.dart';

/// A wrong answer and the wrong turn behind it.
@immutable
class TeaserTrap {
  const TeaserTrap(this.label, this.why);

  final String label;
  final String why;
}

/// One folk puzzle, retold in our own words.
@immutable
class Teaser {
  const Teaser({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.text,
    required this.hints,
    required this.answer,
    required this.traps,
    required this.steps,
    required this.insight,
  });

  final String id;
  final String title;

  /// 1 easy, 2 medium, 3 hard.
  final int difficulty;
  final String text;
  final List<String> hints;
  final String answer;
  final List<TeaserTrap> traps;
  final List<String> steps;

  /// Said when the answer is right.
  final String insight;

  String get difficultyName => const ['Easy', 'Medium', 'Hard'][difficulty - 1];

  String feedbackFor(String picked) => picked == answer
      ? insight
      : traps.firstWhere((t) => t.label == picked).why;
}

const List<Teaser> teasers = [
  Teaser(
    id: 'snail',
    title: 'The snail in the well',
    difficulty: 2,
    text:
        'A snail sits at the bottom of a well 10 metres deep. Every day it '
        'climbs 3 metres, and every night it slides back 2. On which day '
        'does it get out?',
    hints: [
      'Track where it is each morning, not each evening.',
      'Each full day and night it gains 1 metre.',
      'Once it starts a day within 3 metres of the top, that climb gets it '
          'out.',
    ],
    answer: 'Day 8',
    traps: [
      TeaserTrap(
        'Day 10',
        'Day 10 counts 1 metre a day all the way up, but the last climb has '
            'no slide after it.',
      ),
      TeaserTrap(
        'Day 7',
        'Day 7 starts at 6 metres, so its climb only reaches 9.',
      ),
      TeaserTrap('Day 4', 'Day 4 forgets the slide back every night.'),
    ],
    steps: [
      'Each morning it\'s 1 metre higher than the morning before, so day 8 '
          'starts at 7 metres.',
      'That day\'s 3-metre climb reaches the top before any slide.',
      'So it gets out on day 8.',
    ],
    insight: 'Right: the last climb has no slide after it.',
  ),
  Teaser(
    id: 'bat',
    title: 'Bat and ball',
    difficulty: 1,
    text:
        'A bat and a ball cost \$1.10 together. The bat costs \$1.00 more '
        'than the ball. How much is the ball?',
    hints: [
      'Call the ball x. What does the bat cost?',
      'Together: x + (x + \$1.00) = \$1.10.',
      'So 2x = \$0.10.',
    ],
    answer: '5¢',
    traps: [
      TeaserTrap(
        '10¢',
        'With a 10¢ ball the bat is \$1.10, and the two cost \$1.20.',
      ),
      TeaserTrap('1¢', 'With a 1¢ ball the bat is \$1.01: \$1.02 together.'),
      TeaserTrap(
        '55¢',
        '55¢ splits the total evenly, but the bat must cost \$1 more.',
      ),
    ],
    steps: [
      'Ball x, bat x + \$1.00.',
      'Together 2x + \$1.00 = \$1.10, so 2x = \$0.10.',
      'The ball is 5¢ and the bat \$1.05.',
    ],
    insight: 'Right: a 5¢ ball and a \$1.05 bat.',
  ),
  Teaser(
    id: 'lilies',
    title: 'Lilies on the pond',
    difficulty: 1,
    text:
        'A patch of lily pads doubles in size every day. On day 48 it covers '
        'the whole pond. On which day did it cover half?',
    hints: [
      'Work backwards from day 48.',
      'Doubling forwards means halving backwards.',
      'What did the patch cover one day before it was full?',
    ],
    answer: 'Day 47',
    traps: [
      TeaserTrap(
        'Day 24',
        'Halving the days works for steady growth; this patch doubles.',
      ),
      TeaserTrap('Day 46', 'On day 46 it covered a quarter.'),
      TeaserTrap(
        'Day 36',
        'Doubling packs most of the growth into the last few days.',
      ),
    ],
    steps: [
      'Each day the patch is twice the day before.',
      'So the day before full, it was half.',
      'Half the pond on day 47.',
    ],
    insight: 'Right: one day before full, it was half.',
  ),
  Teaser(
    id: 'machines',
    title: 'Busy machines',
    difficulty: 1,
    text:
        'Five machines make five widgets in five minutes. How long do 100 '
        'machines take to make 100 widgets?',
    hints: [
      'How long does one machine take to make one widget?',
      'Each machine works on its own widget at the same time.',
      'More machines make more widgets, not faster ones.',
    ],
    answer: '5 minutes',
    traps: [
      TeaserTrap(
        '100 minutes',
        '100 minutes treats it as one widget a minute overall, but each '
            'machine makes its own.',
      ),
      TeaserTrap(
        '20 minutes',
        '20 scales by 100 ÷ 5, mixing up machines and widgets.',
      ),
      TeaserTrap(
        '1 minute',
        'More machines don\'t make one widget any faster.',
      ),
    ],
    steps: [
      'One machine makes one widget in 5 minutes.',
      '100 machines each make one widget at the same time.',
      'So 100 widgets take 5 minutes.',
    ],
    insight: 'Right: each machine makes one widget in 5 minutes.',
  ),
  Teaser(
    id: 'socks',
    title: 'Socks in the dark',
    difficulty: 1,
    text:
        'A drawer holds 10 black socks and 10 white ones, all loose. In the '
        'dark, how many must you take out to be sure of a matching pair?',
    hints: [
      'There are only two colours.',
      'What\'s the worst that can happen with two socks?',
      'Any third sock must match one of the first two.',
    ],
    answer: '3',
    traps: [
      TeaserTrap('2', 'Two could be one black and one white.'),
      TeaserTrap(
        '11',
        '11 guarantees two black ones, but any matching colour will do.',
      ),
      TeaserTrap('21', 'There are only 20 socks, and 3 is already enough.'),
    ],
    steps: [
      'The first two socks might differ.',
      'The third is black or white, so it matches one of them.',
      'Three socks always make a pair.',
    ],
    insight: 'Right: two colours, so three socks are enough.',
  ),
  Teaser(
    id: 'bridge',
    title: 'The night bridge',
    difficulty: 3,
    text:
        'Four people must cross a narrow bridge at night with one torch. At '
        'most two cross at once, at the slower one\'s pace, and the torch '
        'goes on every crossing. They take 1, 2, 5 and 10 minutes. What\'s '
        'the shortest total time?',
    hints: [
      'Someone has to bring the torch back each time.',
      'The two slowest are cheapest if they cross together.',
      'Get the two fastest to the far side first, so one can bring the '
          'torch back later.',
    ],
    answer: '17 minutes',
    traps: [
      TeaserTrap(
        '19 minutes',
        '19 sends the fastest walker with everyone. Sending the two slowest '
            'together saves 2 minutes.',
      ),
      TeaserTrap(
        '16 minutes',
        'The torch must come back twice and the 10 and 5 must cross: 17 is '
            'the least.',
      ),
      TeaserTrap(
        '18 minutes',
        'Every plan that sends the 10 and 5 apart takes at least 19.',
      ),
    ],
    steps: [
      '1 and 2 cross (2 minutes); 1 brings the torch back (1).',
      '5 and 10 cross together (10); 2 brings it back (2).',
      '1 and 2 cross again (2): 2 + 1 + 10 + 2 + 2 = 17.',
    ],
    insight: 'Right: send the two slowest across together.',
  ),
  Teaser(
    id: 'river',
    title: 'Wolf, goat and cabbage',
    difficulty: 2,
    text:
        'A farmer must ferry a wolf, a goat and a cabbage across a river. '
        'The boat holds the farmer and one of them. Left alone, the wolf '
        'eats the goat and the goat eats the cabbage. What\'s the fewest '
        'crossings, counting each way?',
    hints: [
      'The goat is the trouble: it can\'t be left with either of the others.',
      'Take the goat first.',
      'Something may have to come back the other way.',
    ],
    answer: '7',
    traps: [
      TeaserTrap(
        '5',
        'Five would mean nothing ever comes back, but the goat has to make '
            'a return trip.',
      ),
      TeaserTrap(
        '3',
        'Each passenger needs its own trip over, with the farmer rowing back '
            'between.',
      ),
      TeaserTrap('9', 'It can be done in fewer: bring the goat back once.'),
    ],
    steps: [
      'Take the goat over and come back alone (2 crossings).',
      'Take the wolf over and bring the goat back (4).',
      'Take the cabbage over, come back alone, take the goat over (7).',
    ],
    insight: 'Right: the goat goes over, comes back, and goes over again.',
  ),
  Teaser(
    id: 'clock315',
    title: 'A quarter past three',
    difficulty: 2,
    text:
        'At exactly 3:15, what is the angle between the hour hand and the '
        'minute hand?',
    hints: [
      'Where is the minute hand at 15 minutes past?',
      'The hour hand doesn\'t wait for the hour: it moves steadily.',
      'The hour hand moves 30° an hour.',
    ],
    answer: '7.5°',
    traps: [
      TeaserTrap(
        '0°',
        '0° forgets that the hour hand has moved a quarter of the way from '
            '3 to 4.',
      ),
      TeaserTrap('90°', '90° is the minute hand\'s angle from 12.'),
      TeaserTrap('15°', '15° doubles the hour hand\'s drift.'),
    ],
    steps: [
      'The minute hand points at 3: 90° from 12.',
      'The hour hand moves 30° an hour, so a quarter hour puts it 7.5° past '
          '3.',
      'The gap is 7.5°.',
    ],
    insight: 'Right: the hour hand has crept 7.5° past the 3.',
  ),
  Teaser(
    id: 'fly',
    title: 'The fly between trains',
    difficulty: 2,
    text:
        'Two trains 100 km apart head toward each other, each at 50 km/h. A '
        'fly starts at one and flies back and forth between them at 75 km/h '
        'until they meet. How far does the fly travel?',
    hints: [
      'Don\'t follow the zigzags.',
      'How long until the trains meet?',
      'The fly never stops flying.',
    ],
    answer: '75 km',
    traps: [
      TeaserTrap('100 km', '100 km is the gap between the trains.'),
      TeaserTrap('150 km', 'The trains meet after 1 hour, not 2.'),
      TeaserTrap('50 km', '50 km is how far each train travels.'),
    ],
    steps: [
      'The gap closes at 50 + 50 = 100 km/h, so they meet in 1 hour.',
      'The fly flies for that whole hour at 75 km/h.',
      'So it covers 75 km.',
    ],
    insight: 'Right: one hour of flying at 75 km/h.',
  ),
  Teaser(
    id: 'birthdays',
    title: 'Shared birthdays',
    difficulty: 3,
    text:
        'How many people do you need in a room for a better-than-even chance '
        'that two of them share a birthday? Ignore leap years.',
    hints: [
      'Think about pairs of people, not people.',
      'Work out the chance that nobody shares.',
      'Multiply 365/365 × 364/365 × 363/365 … until it drops below 1/2.',
    ],
    answer: '23',
    traps: [
      TeaserTrap(
        '183',
        '183 is half of 365, but the number of pairs grows much faster than '
            'the number of people.',
      ),
      TeaserTrap(
        '366',
        '366 makes a shared birthday certain, not just likely.',
      ),
      TeaserTrap('57', 'At 57 people the chance is already about 99%.'),
    ],
    steps: [
      'n people make n(n − 1)/2 pairs, and each pair might match.',
      'The chance nobody matches, 365/365 × 364/365 × …, falls below 1/2 at '
          '23 people.',
      '23 people already make 253 pairs.',
    ],
    insight: 'Right: 23 people make 253 pairs.',
  ),
  Teaser(
    id: 'doors3',
    title: 'Three doors',
    difficulty: 2,
    text:
        'A prize is behind one of three doors. You pick door 1. The host, '
        'who knows where the prize is, opens another door with nothing '
        'behind it and offers you a switch. If you switch, what\'s your '
        'chance of winning?',
    hints: [
      'How likely was your first pick to be right?',
      'The host never opens the prize door.',
      'If your first pick was wrong, where does switching take you?',
    ],
    answer: '2/3',
    traps: [
      TeaserTrap(
        '1/2',
        'Two doors are left, but not equally likely: the host\'s choice '
            'isn\'t random.',
      ),
      TeaserTrap('1/3', '1/3 is your chance if you stay.'),
      TeaserTrap('1', 'Switching loses when your first pick was right.'),
    ],
    steps: [
      'Your first pick is right 1/3 of the time.',
      'The other 2/3, the host has to open the other empty door, so '
          'switching lands on the prize.',
      'Switching wins 2/3 of the time.',
    ],
    insight: 'Right: switching wins whenever your first pick was wrong.',
  ),
  Teaser(
    id: 'children',
    title: 'Two children',
    difficulty: 2,
    text:
        'A family has two children, and at least one of them is a boy. '
        'What\'s the chance both are boys?',
    hints: [
      'List the equally likely families, oldest first.',
      'Which of them does "at least one boy" rule out?',
      'Count what\'s left.',
    ],
    answer: '1/3',
    traps: [
      TeaserTrap(
        '1/2',
        '1/2 is the chance if you\'re told the older one is a boy.',
      ),
      TeaserTrap('1/4', '1/4 is the chance before you hear about the boy.'),
      TeaserTrap('2/3', '2/3 is the chance of one boy and one girl.'),
    ],
    steps: [
      'Equally likely: boy-boy, boy-girl, girl-boy, girl-girl.',
      'At least one boy rules out girl-girl, leaving three.',
      'Only one of those three is boy-boy: 1/3.',
    ],
    insight: 'Right: three families fit, and one is boy-boy.',
  ),
  Teaser(
    id: 'guards',
    title: 'Two guards',
    difficulty: 2,
    text:
        'Two doors: one leads out. One guard always lies and the other '
        'always tells the truth, and you can\'t tell them apart. You may '
        'ask one guard one yes-or-no question. What do you ask?',
    hints: [
      'A plain question gets a true or a false answer, and you won\'t know '
          'which.',
      'Make both guards\' answers come out the same.',
      'Bring the other guard into the question.',
    ],
    answer: '"Would the other guard say this door leads out?"',
    traps: [
      TeaserTrap(
        '"Does this door lead out?"',
        'The liar answers it falsely, and you don\'t know who\'s lying.',
      ),
      TeaserTrap(
        '"Are you the one who lies?"',
        'Both guards say no, so you learn nothing.',
      ),
      TeaserTrap(
        '"Is the sky blue?"',
        'You\'d find the liar, but you\'ve used your only question.',
      ),
    ],
    steps: [
      'Asking about the other guard passes the answer through both: one '
          'truth and one lie.',
      'So the reply always points the wrong way.',
      'Ask, then do the opposite.',
    ],
    insight: 'Right: the answer is always wrong, so do the opposite.',
  ),
  Teaser(
    id: 'hundredDoors',
    title: 'A hundred doors',
    difficulty: 3,
    text:
        '100 doors start closed. On pass 1 you flip every door, on pass 2 '
        'every 2nd door, on pass 3 every 3rd, and so on up to pass 100. How '
        'many doors end up open?',
    hints: [
      'Door 12 is flipped on passes 1, 2, 3, 4, 6 and 12.',
      'A door ends open if it\'s flipped an odd number of times.',
      'Divisors come in pairs. When don\'t they?',
    ],
    answer: '10',
    traps: [
      TeaserTrap(
        '50',
        '50 would be right if doors were flipped once or twice; they\'re '
            'flipped once per divisor.',
      ),
      TeaserTrap('0', 'Some doors are flipped an odd number of times.'),
      TeaserTrap(
        '1',
        'More doors than door 1 are flipped an odd number of times.',
      ),
    ],
    steps: [
      'Door n is flipped once for each number that divides n.',
      'Divisors pair up (2 with 6 for 12), except a square\'s root, which '
          'pairs with itself.',
      'So only squares (1, 4, 9 … 100) end up open: 10 doors.',
    ],
    insight: 'Right: only the square-numbered doors stay open.',
  ),
  Teaser(
    id: 'ages',
    title: 'Mother and son',
    difficulty: 1,
    text:
        'A mother is 4 times as old as her son. In 20 years she\'ll be twice '
        'as old as him. How old is the son now?',
    hints: [
      'Call the son\'s age s.',
      'In 20 years: 4s + 20 = 2(s + 20).',
      'Solve for s.',
    ],
    answer: '10',
    traps: [
      TeaserTrap('5', 'Then she\'s 20; in 20 years, 40 and 25: not twice.'),
      TeaserTrap('20', 'Then she\'s 80; in 20 years, 100 and 40: not twice.'),
      TeaserTrap('40', '40 is the mother\'s age.'),
    ],
    steps: [
      'Son s, mother 4s.',
      'In 20 years: 4s + 20 = 2(s + 20), so 2s = 20.',
      'The son is 10 and the mother 40.',
    ],
    insight: 'Right: 10 and 40 now, 30 and 60 in 20 years.',
  ),
  Teaser(
    id: 'speed',
    title: 'There and back',
    difficulty: 2,
    text:
        'You drive to a town at 60 km/h and come back the same way at '
        '30 km/h. What\'s your average speed for the round trip?',
    hints: [
      'Pick a distance, say 60 km each way.',
      'How long does each leg take?',
      'Average speed is total distance ÷ total time.',
    ],
    answer: '40 km/h',
    traps: [
      TeaserTrap(
        '45 km/h',
        '45 averages the speeds, but you spend twice as long on the slow '
            'leg.',
      ),
      TeaserTrap('50 km/h', 'The slow leg pulls the average below 45.'),
      TeaserTrap('30 km/h', '30 is the slow leg alone.'),
    ],
    steps: [
      'Say it\'s 60 km each way: 1 hour there, 2 hours back.',
      '120 km in 3 hours.',
      'That\'s 40 km/h.',
    ],
    insight: 'Right: more time at the slow speed pulls the average down.',
  ),
  Teaser(
    id: 'brick',
    title: 'Half a brick',
    difficulty: 1,
    text:
        'A brick weighs 1 kg plus half a brick. What does a whole brick weigh?',
    hints: [
      'Write it as an equation: brick = 1 kg + brick ÷ 2.',
      'Take half a brick from both sides.',
      'What does half a brick weigh?',
    ],
    answer: '2 kg',
    traps: [
      TeaserTrap('1.5 kg', '1.5 kg reads "half a brick" as half a kilo.'),
      TeaserTrap('1 kg', '1 kg leaves out the half brick.'),
      TeaserTrap('3 kg', 'Then half a brick would be 1.5 kg: 2.5 kg in all.'),
    ],
    steps: [
      'Brick = 1 kg + half a brick.',
      'So the other half a brick weighs 1 kg.',
      'A whole brick weighs 2 kg.',
    ],
    insight: 'Right: half a brick is 1 kg.',
  ),
  Teaser(
    id: 'pancake',
    title: 'Three cuts',
    difficulty: 2,
    text:
        'With 3 straight cuts across a flat pancake, and no stacking, '
        'what\'s the most pieces you can make?',
    hints: [
      'Cuts through the centre aren\'t the best.',
      'A new cut adds one piece, plus one for each earlier cut it crosses.',
      'Make every cut cross every other one, at different points.',
    ],
    answer: '7',
    traps: [
      TeaserTrap(
        '6',
        'Three cuts through one point make 6; spread the crossings out.',
      ),
      TeaserTrap('8', '8 needs stacking or a cut through the thickness.'),
      TeaserTrap('9', 'A third cut can add at most 3 pieces to 4.'),
    ],
    steps: [
      'Cut 1 makes 2 pieces; cut 2 crosses it and adds 2: 4.',
      'Cut 3 crosses both, at different points, and adds 3: 7.',
      'No cut can add more than one plus the cuts it crosses.',
    ],
    insight: 'Right: 1 + 1 + 2 + 3 = 7.',
  ),
  Teaser(
    id: 'days',
    title: 'Day after tomorrow',
    difficulty: 1,
    text: 'If the day after tomorrow is Sunday, what day was yesterday?',
    hints: [
      'Find today first.',
      'Two days before Sunday.',
      'Then one day back from today.',
    ],
    answer: 'Thursday',
    traps: [
      TeaserTrap('Friday', 'Friday is today.'),
      TeaserTrap('Saturday', 'Saturday is tomorrow.'),
      TeaserTrap('Wednesday', 'Wednesday goes back one day too many.'),
    ],
    steps: [
      'The day after tomorrow is Sunday, so today is Friday.',
      'Yesterday was Thursday.',
    ],
    insight: 'Right: today is Friday.',
  ),
  Teaser(
    id: 'overlaps',
    title: 'Hands together',
    difficulty: 2,
    text:
        'In 12 hours, how many times do a clock\'s hour and minute hands '
        'point exactly the same way?',
    hints: [
      'The minute hand laps the hour hand.',
      'Between 11 and 1, do they meet more than once?',
      'The minute hand gains a full lap every 12/11 of an hour.',
    ],
    answer: '11',
    traps: [
      TeaserTrap(
        '12',
        '12 counts one meeting per hour, but there\'s none between 11:00 '
            'and 12:00 apart from 12:00 itself.',
      ),
      TeaserTrap(
        '24',
        '24 is two an hour, but they meet less than once an hour.',
      ),
      TeaserTrap('22', '22 is for a full day.'),
    ],
    steps: [
      'The minute hand goes round 12 times while the hour hand goes round '
          'once.',
      'So it laps the hour hand 12 − 1 = 11 times.',
      'They meet 11 times, about every 65 minutes.',
    ],
    insight: 'Right: 12 laps minus the hour hand\'s 1.',
  ),
  Teaser(
    id: 'chess',
    title: 'Squares on a chessboard',
    difficulty: 2,
    text: 'How many squares of any size are there on an 8 by 8 chessboard?',
    hints: [
      'Count by size: 1 by 1, 2 by 2, and so on.',
      'How many places does a 2 by 2 square fit?',
      'A k by k square fits in (9 − k) × (9 − k) places.',
    ],
    answer: '204',
    traps: [
      TeaserTrap('64', '64 counts only the smallest squares.'),
      TeaserTrap(
        '65',
        '65 adds the whole board, but there are sizes in between.',
      ),
      TeaserTrap('120', 'Count every size: 64 + 49 + 36 + … + 1.'),
    ],
    steps: [
      'A k by k square fits in (9 − k)² places.',
      '64 + 49 + 36 + 25 + 16 + 9 + 4 + 1.',
      'That\'s 204 squares.',
    ],
    insight: 'Right: the sum of the squares from 1 to 64.',
  ),
  Teaser(
    id: 'fruit',
    title: 'Wrong labels',
    difficulty: 2,
    text:
        'Three boxes are labelled Apples, Oranges and Mixed, and every label '
        'is wrong. You may take one fruit from one box without looking in. '
        'Which box do you take it from to fix every label?',
    hints: [
      'Every label is wrong. What does that tell you about "Mixed"?',
      'The box labelled Mixed holds only one kind of fruit.',
      'One fruit from it tells you what it really holds.',
    ],
    answer: 'The one labelled Mixed',
    traps: [
      TeaserTrap(
        'The one labelled Apples',
        'It holds oranges or mixed fruit. An orange from it doesn\'t tell '
            'you which.',
      ),
      TeaserTrap(
        'The one labelled Oranges',
        'It holds apples or mixed fruit. An apple from it doesn\'t tell you '
            'which.',
      ),
      TeaserTrap(
        'One fruit isn\'t enough',
        'It is, from the box labelled Mixed.',
      ),
    ],
    steps: [
      'The box labelled Mixed must hold only apples or only oranges.',
      'Draw from it: say an apple, so it\'s the Apples box.',
      'The box labelled Oranges can\'t be oranges or apples now: it\'s '
          'Mixed. The last box is Oranges.',
    ],
    insight: 'Right: the Mixed box can only hold one kind.',
  ),
  Teaser(
    id: 'eggs',
    title: 'Two eggs, 100 floors',
    difficulty: 3,
    text:
        'You have two identical eggs and a 100-floor building. Find the '
        'highest floor an egg survives a drop from. A broken egg is gone. '
        'What\'s the fewest drops that always works?',
    hints: [
      'Once the first egg breaks, the second must go floor by floor.',
      'Make every outcome cost the same number of drops.',
      'With d drops, drop the first egg from floor d, then d + (d − 1), and '
          'so on.',
    ],
    answer: '14',
    traps: [
      TeaserTrap(
        '10',
        'Steps of 10 can need 10 drops for the first egg plus 9 for the '
            'second: 19.',
      ),
      TeaserTrap('50', 'Halving works with plenty of eggs, not two.'),
      TeaserTrap('7', '7 drops cover at most 28 floors with two eggs.'),
    ],
    steps: [
      'With d drops, the first egg goes up d floors, then d − 1, then '
          'd − 2 …',
      'That covers d + (d − 1) + … + 1 = d(d + 1)/2 floors.',
      '14 × 15 / 2 = 105 covers 100; 13 × 14 / 2 = 91 doesn\'t.',
    ],
    insight: 'Right: shrinking steps of 14, 13, 12 … cover 105 floors.',
  ),
  Teaser(
    id: 'photo',
    title: 'The photograph',
    difficulty: 2,
    text:
        'Looking at a photo, a man says: "I have no brothers or sisters, but '
        'that man\'s father is my father\'s son." Who is in the photo?',
    hints: [
      'Who is "my father\'s son", for a man with no brothers?',
      'So the man in the photo has the speaker as his father.',
      'Who has the speaker as a father?',
    ],
    answer: 'His son',
    traps: [
      TeaserTrap(
        'Himself',
        '"My father\'s son" is himself, so he\'s the photo man\'s father.',
      ),
      TeaserTrap('His father', 'That would make him his own grandfather.'),
      TeaserTrap('His brother', 'He has no brothers.'),
    ],
    steps: [
      'With no brothers, "my father\'s son" is the speaker.',
      'So the man in the photo has the speaker as his father.',
      'It\'s his son.',
    ],
    insight: 'Right: "my father\'s son" is the speaker himself.',
  ),
  Teaser(
    id: 'switches',
    title: 'Three switches',
    difficulty: 2,
    text:
        'Three switches downstairs control one bulb upstairs. You may flip '
        'them as you like, then go up just once. How can you tell which '
        'switch works the bulb?',
    hints: [
      'Light isn\'t the only thing a bulb gives off.',
      'A bulb that was on stays warm for a while.',
      'Use on, off-after-a-while, and never touched.',
    ],
    answer: 'Leave one on for a while, switch it off, turn another on, go up',
    traps: [
      TeaserTrap(
        'Turn them on one at a time and listen',
        'You can\'t see or hear the bulb from downstairs.',
      ),
      TeaserTrap(
        'Turn two on and go up',
        'If it\'s lit you still can\'t tell which of the two.',
      ),
      TeaserTrap(
        'It can\'t be done in one visit',
        'It can: the bulb\'s warmth tells you a second thing.',
      ),
    ],
    steps: [
      'Lit: the switch that\'s on now.',
      'Dark but warm: the one you switched off.',
      'Dark and cold: the one you never touched.',
    ],
    insight: 'Right: light and heat give three different results.',
  ),
  Teaser(
    id: 'eightBalls',
    title: 'The heavy ball',
    difficulty: 2,
    text:
        'Eight balls look alike, but one is heavier. With a balance scale, '
        'what\'s the fewest weighings that always finds it?',
    hints: [
      'A weighing has three results, not two.',
      'Split into three groups.',
      'Weigh 3 against 3.',
    ],
    answer: '2',
    traps: [
      TeaserTrap(
        '3',
        'Halving takes 3, but a weighing can also balance: three results.',
      ),
      TeaserTrap('1', 'One weighing can tell at most 3 balls apart.'),
      TeaserTrap('4', 'Splitting into thirds needs only 2.'),
    ],
    steps: [
      'Weigh 3 against 3.',
      'If they balance, weigh the last 2. If not, take the heavier 3 and '
          'weigh 1 against 1.',
      'Either way, 2 weighings find it.',
    ],
    insight: 'Right: three results per weighing, so thirds.',
  ),
  Teaser(
    id: 'ropes',
    title: 'Burning ropes',
    difficulty: 3,
    text:
        'Two ropes each take exactly an hour to burn, but they burn '
        'unevenly, so half a rope isn\'t half an hour. How do you time 45 '
        'minutes?',
    hints: [
      'Lighting a rope at both ends changes how long it lasts.',
      'A rope lit at both ends burns out in 30 minutes, however uneven.',
      'Start both ropes at once.',
    ],
    answer:
        'Light A at both ends and B at one; when A is gone, light B\'s '
        'other end',
    traps: [
      TeaserTrap(
        'Burn A halfway, then B a quarter',
        'Uneven burning means half its length isn\'t half an hour.',
      ),
      TeaserTrap(
        'Light both ropes at both ends',
        'That times 30 minutes, not 45.',
      ),
      TeaserTrap(
        'Light A and stop when three quarters has burned',
        'Uneven burning: three quarters of the length isn\'t 45 minutes.',
      ),
    ],
    steps: [
      'Lit at both ends, rope A burns out in 30 minutes.',
      'Rope B, lit at one end, has 30 minutes left then; light its other '
          'end.',
      'B now lasts 15 more minutes: 45 in all.',
    ],
    insight: 'Right: 30 minutes, then half of the 30 left.',
  ),
  Teaser(
    id: 'wine',
    title: 'Wine and water',
    difficulty: 3,
    text:
        'Take a spoonful from a glass of wine into a glass of water and '
        'stir. Then take a spoonful of that mix back into the wine. Is there '
        'more water in the wine, or more wine in the water?',
    hints: [
      'How much is in each glass at the end?',
      'Each glass ends with the amount it started with.',
      'Whatever wine left the wine glass has been replaced by something.',
    ],
    answer: 'The same',
    traps: [
      TeaserTrap(
        'More wine in the water',
        'The spoon that went back carried some of that wine home.',
      ),
      TeaserTrap(
        'More water in the wine',
        'Each glass ends as full as it began, so the swaps match.',
      ),
      TeaserTrap('It depends on the spoon', 'Any spoon gives the same answer.'),
    ],
    steps: [
      'Both glasses end with the amount they started with.',
      'So whatever wine is missing from the wine glass was replaced by '
          'exactly that much water.',
      'That missing wine is in the water: the amounts are equal.',
    ],
    insight: 'Right: every bit of wine that left was replaced by water.',
  ),
  Teaser(
    id: 'dollar',
    title: 'The missing dollar',
    difficulty: 2,
    text:
        'Three friends pay \$30 for a room. The clerk finds it costs \$25 '
        'and sends \$5 back with the porter, who keeps \$2 and returns \$1 '
        'each. So each paid \$9: 3 × 9 = 27, plus the porter\'s 2 makes 29. '
        'Where\'s the missing dollar?',
    hints: [
      'Where did the friends\' \$27 go?',
      '\$25 to the hotel and \$2 to the porter.',
      'Should the porter\'s \$2 be added to the 27?',
    ],
    answer: 'Nothing\'s missing: the \$27 includes the porter\'s \$2',
    traps: [
      TeaserTrap('The porter kept it', 'He kept \$2, and that\'s counted.'),
      TeaserTrap(
        'The clerk has it',
        'The clerk has \$25, which is part of the \$27.',
      ),
      TeaserTrap(
        'It was lost in the change',
        'Every dollar is accounted for: 25 + 2 + 3 = 30.',
      ),
    ],
    steps: [
      'The friends paid \$27 in all.',
      'That\'s \$25 to the hotel plus \$2 to the porter.',
      'Adding the \$2 again counts it twice; 27 + the 3 returned = 30.',
    ],
    insight: 'Right: the puzzle adds the porter\'s \$2 twice.',
  ),
  Teaser(
    id: 'folds',
    title: 'Folding paper',
    difficulty: 1,
    text:
        'Fold a sheet of paper in half 10 times. How many layers thick is it?',
    hints: [
      'What does one fold do to the layers?',
      'Each fold doubles them.',
      '2 × 2 × … ten times.',
    ],
    answer: '1,024',
    traps: [
      TeaserTrap('20', '20 adds two layers a fold, but each fold doubles.'),
      TeaserTrap('512', '512 is 9 folds.'),
      TeaserTrap('100', '100 squares the folds instead of doubling.'),
    ],
    steps: ['Each fold doubles the layers.', '2 to the power 10 = 1,024.'],
    insight: 'Right: ten doublings make 1,024.',
  ),
];
