import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'memes.dart';
import 'native.dart';
import 'theme.dart';

const _termsVersion = 'Terms and privacy, version 1';

class _Section {
  final String title;
  final String body;
  const _Section(this.title, this.body);
}

const _sections = [
  _Section(
    'What DoomPal is',
    'DoomPal is a free, open-source app that counts the reels and Shorts you scroll, helps you cut down, '
        'and blocks them when you reach limits you set. Doomy is its mascot. DoomPal is a personal project, '
        'not a company, and it has no accounts.',
  ),
  _Section(
    'What it can see',
    'To count, DoomPal uses Android\'s Accessibility service, only for YouTube, Instagram, Facebook and '
        'Snapchat. It sees which screen you are on and when you scroll. It also reads on-screen labels like '
        '"Ad" so it can skip ads. It does not read your messages, passwords or comments, does not take '
        'screenshots, and does not keep any text it reads. If you turn on the detection log, it saves '
        'technical screen names (not content) so detection can be fixed.',
  ),
  _Section(
    'What it keeps on your phone',
    'How many you scroll each day and each hour, a time estimate, your settings, your chat with Doomy, any '
        'pictures you add, and a few timing numbers about how you scroll (the pause between reels and how '
        'long a swipe takes). It does not keep what you watched, who you follow, or any account details.',
  ),
  _Section(
    'Nothing leaves your phone',
    'DoomPal has no internet permission, so it cannot send anything anywhere. No accounts, no analytics, no '
        'ad network. The "ads" Doomy shows are jokes made inside the app. You can check this yourself in '
        'Android Settings, Apps, DoomPal, Permissions.',
  ),
  _Section(
    'How Doomy learns',
    'Doomy learns from your habits using simple statistics saved on this phone: which hours you scroll most, how '
        'often you hit your limits or beg, and how you usually scroll. It uses that to tighten limits when '
        'you keep slipping and ease back toward your own limit when you do well. It never goes looser than '
        'the limit you set. It is not a cloud AI, and deleting the app\'s data erases everything it learned.',
  ),
  _Section(
    'The lock',
    'Making a limit stricter takes effect at once. Making it looser, or turning something off, waits for '
        'a cooldown you choose (24 hours to start). This is a speed bump you set up for yourself. It cannot stop '
        'you turning off Accessibility, uninstalling the app, or changing your phone\'s clock.',
  ),
  _Section(
    'Guest pass and fingerprints',
    'A guest pass lets someone else use reels for a short time. It asks for a fingerprint saved on your '
        'phone, using Android\'s own prompt. DoomPal never sees fingerprint data, and Android cannot tell it '
        'whose finger it was. After that, Doomy compares how the guest\'s first 10 swipes are made with how you '
        'usually scroll, and cancels the pass if they look like yours. That check is a rough guess and can be '
        'wrong in both directions. Adding someone\'s fingerprint to your phone lets '
        'them unlock it, so only do that if you are fine with it.',
  ),
  _Section(
    'Your health',
    'DoomPal is not a medical device and gives no medical advice. Eye breaks and bedtime blocks are '
        'general wellbeing nudges. If your phone use is hurting your sleep, mood, school or work, talk to someone '
        'you trust or a health professional.',
  ),
  _Section(
    'If you are under 18',
    'Please use DoomPal with a parent or guardian\'s OK, since it asks for Accessibility access to your phone.',
  ),
  _Section(
    'Your choices',
    'You can delete your history, your pictures and your chat in the app. While the lock is on, deleting '
        'history keeps today\'s numbers so it can\'t be used to reset a limit. Uninstalling the app removes '
        'everything it stored.',
  ),
  _Section(
    'No promises',
    'DoomPal is open source under the MIT licence and comes as is, with no warranty. YouTube and the other '
        'apps change often, so counting may sometimes be off or stop working until DoomPal is updated. '
        'This is a plain-language summary, not legal advice.',
  ),
];

/// First-run agreement, also reachable later from Rules.
class TermsPage extends StatefulWidget {
  final bool readOnly;
  final VoidCallback? onAccepted;
  const TermsPage({super.key, this.readOnly = false, this.onAccepted});

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  bool _checked = false;
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await Native.setSetting('terms', 1);
    } catch (_) {}
    if (!mounted) return;
    widget.onAccepted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (!widget.readOnly) ...[
          const Center(child: DoomyAvatar('judge', size: 110)),
          const SizedBox(height: 10),
          const Center(child: Text('Before we start', style: Txt.heading)),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'The short version: everything stays on your phone.',
              style: Txt.quiet,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 18),
        ],
        for (final sec in _sections) ...[
          Text(sec.title, style: Txt.title),
          const SizedBox(height: 4),
          Text(sec.body, style: Txt.quiet),
          const SizedBox(height: 18),
        ],
        const Text(_termsVersion, style: Txt.small),
      ],
    );
    if (widget.readOnly) {
      return Scaffold(appBar: AppBar(title: const Text('Terms and privacy')), body: body);
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: body),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: _checked,
                    onChanged: (v) => setState(() => _checked = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: Palette.doomy,
                    checkColor: Palette.ink,
                    title: const Text('I have read this and I agree', style: Txt.body),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => SystemNavigator.pop(),
                          child: const Text('No thanks'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: (_checked && !_busy) ? _accept : null,
                          child: const Text('I agree'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
