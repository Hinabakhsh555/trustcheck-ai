import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TrustCheckApp());
}

class TrustCheckApp extends StatelessWidget {
  const TrustCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TrustCheck AI',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF175CD3),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;
  int _tab = 0;
  final List<RiskResult> _history = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    setState(() => _busy = true);
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
      if (image == null) return;
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final input = InputImage.fromFilePath(image.path);
        final result = await recognizer.processImage(input);
        if (!mounted) return;
        _controller.text = result.text;
        if (result.text.trim().isEmpty) {
          _snack('No readable Latin/Roman-Urdu text was found. You can paste the text manually.');
        }
      } finally {
        await recognizer.close();
      }
    } catch (_) {
      if (mounted) _snack('The screenshot could not be processed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _check() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _snack('Paste a suspicious message or choose a screenshot first.');
      return;
    }
    final result = RiskEngine().analyze(text);
    setState(() => _history.insert(0, result));
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(result: result)));
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.shield_outlined),
          SizedBox(width: 8),
          Text('TrustCheck AI', style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _CheckView(
            controller: _controller,
            busy: _busy,
            onPickScreenshot: _pickScreenshot,
            onCheck: _check,
          ),
          HistoryView(history: _history),
          const LearnView(),
          const AboutView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Check'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Learn'),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'About'),
        ],
      ),
    );
  }
}

class _CheckView extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onPickScreenshot;
  final VoidCallback onCheck;

  const _CheckView({
    required this.controller,
    required this.busy,
    required this.onPickScreenshot,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Check before you trust.', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.7)),
          const SizedBox(height: 8),
          Text(
            'Paste a suspicious SMS, WhatsApp, marketplace, banking, job or investment message. TrustCheck explains the warning signs instead of giving a black-box verdict.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 22),
          TextField(
            controller: controller,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: 'Suspicious message',
              hintText: 'Example: Your account will be blocked. Send your OTP immediately...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: busy ? null : onCheck,
            icon: const Icon(Icons.search),
            label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Check message')),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : onPickScreenshot,
            icon: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.image_outlined),
            label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Choose screenshot')),
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.lock_outline),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  'Privacy-first V1: screenshot text recognition runs on the device. The app does not automatically read SMS, WhatsApp, contacts, calls or notifications.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Supports English, Roman Urdu and common Urdu scam phrases for message analysis.'),
        ],
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  final RiskResult result;
  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final color = switch (result.level) {
      RiskLevel.low => Colors.green.shade700,
      RiskLevel.medium => Colors.orange.shade800,
      RiskLevel.high => Theme.of(context).colorScheme.error,
    };
    final label = switch (result.level) {
      RiskLevel.low => 'LOW RISK',
      RiskLevel.medium => 'MEDIUM RISK',
      RiskLevel.high => 'HIGH RISK',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Risk analysis')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(children: [
                Icon(result.level == RiskLevel.high ? Icons.gpp_bad_outlined : Icons.shield_outlined, size: 54, color: color),
                const SizedBox(height: 10),
                Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                const SizedBox(height: 6),
                Text('${result.score}/100', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(result.category, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Text(result.summary, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          Text('Why it was flagged', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (result.signals.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No strong common scam indicator was detected. This does not prove the message is legitimate.')))
          else
            ...result.signals.map((s) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('+${s.points}')),
                title: Text(s.title),
                subtitle: Text(s.detail),
              ),
            )),
          const SizedBox(height: 20),
          Text('Recommended action', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          ...result.actions.map((a) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle_outline),
            title: Text(a),
          )),
          const SizedBox(height: 16),
          const Text('TrustCheck provides a risk assessment, not a guarantee that a message is fraudulent or legitimate.', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class HistoryView extends StatelessWidget {
  final List<RiskResult> history;
  const HistoryView({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(28), child: Text('No checks yet. Your checks from this session will appear here.')));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, i) {
        final r = history[i];
        return Card(child: ListTile(
          leading: Icon(r.level == RiskLevel.high ? Icons.warning_amber_rounded : Icons.shield_outlined),
          title: Text('${r.score}/100 · ${r.category}'),
          subtitle: Text(r.text, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(result: r))),
        ));
      },
    );
  }
}

class LearnView extends StatelessWidget {
  const LearnView({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('OTP & PIN requests', 'Never share an OTP, PIN, password, recovery phrase or private key with another person.'),
      ('Urgency and threats', 'Scammers create pressure: “act now”, “account blocked”, “police case”, or artificial deadlines.'),
      ('Unexpected payments', 'Verify the recipient independently before paying a fee, deposit, courier charge or investment.'),
      ('Job/task scams', 'Be cautious when a job promises unusually easy earnings or asks you to deposit money first.'),
      ('Investment scams', 'Guaranteed or fixed high returns and “double your money” claims are major warning signs.'),
      ('Suspicious links', 'Open the organization’s official app/site yourself rather than trusting a link inside a message.'),
    ];
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('Scam warning signs', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...items.map((x) => Card(child: ListTile(title: Text(x.$1, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(x.$2)))),
      ],
    );
  }
}

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('TrustCheck AI', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Version 1.0.0'),
        const SizedBox(height: 22),
        const Card(child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('TrustCheck is designed to help users identify common fraud, phishing, impersonation and social-engineering indicators. It does not accuse a sender of a crime and should be combined with independent verification.'),
        )),
        const SizedBox(height: 10),
        const Card(child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('For urgent financial concerns, contact the bank/payment provider through a trusted official channel. Do not use phone numbers or links supplied by a suspicious message.'),
        )),
      ],
    );
  }
}

enum RiskLevel { low, medium, high }

class RiskSignal {
  final String title;
  final String detail;
  final int points;
  const RiskSignal(this.title, this.detail, this.points);
}

class RiskResult {
  final String text;
  final int score;
  final RiskLevel level;
  final String category;
  final String summary;
  final List<RiskSignal> signals;
  final List<String> actions;
  const RiskResult({required this.text, required this.score, required this.level, required this.category, required this.summary, required this.signals, required this.actions});
}

class _Rule {
  final RegExp regex;
  final String title;
  final String detail;
  final int points;
  const _Rule(this.regex, this.title, this.detail, this.points);
}

class RiskEngine {
  static final RegExp _url = RegExp(r'((https?:\/\/|www\.)[^\s]+|(?:[a-z0-9-]+\.)+(?:com|net|org|pk|xyz|top|click|info|live|site)\b[^\s]*)', caseSensitive: false);

  final List<_Rule> rules = [
    _Rule(RegExp(r'\b(otp|one[ -]?time password|verification code|pin|password)\b', caseSensitive: false), 'Requests a security credential', 'Legitimate services should not ask you to send an OTP, PIN or password to another person.', 30),
    _Rule(RegExp(r'\b(urgent|immediately|act now|foran|forun|jaldi|abhi|فوری|فوراً|جلدی)\b', caseSensitive: false), 'Creates urgency', 'Pressure and artificial deadlines are common social-engineering techniques.', 12),
    _Rule(RegExp(r'(account.{0,20}(blocked|suspended|closed)|verify.{0,15}account|اکاؤنٹ.{0,20}(بند|بلاک))', caseSensitive: false), 'Threatens account restriction', 'The message may be using fear of account loss to force quick action.', 18),
    _Rule(RegExp(r'\b(send|transfer|pay|deposit|bhejo|bhejein|jama)\b.{0,45}\b(money|cash|fee|payment|rs|pkr|usd|usdt|paisa|rupees)\b', caseSensitive: false), 'Requests money', 'Unexpected payment or transfer requests materially increase fraud risk.', 20),
    _Rule(RegExp(r'\b(guaranteed|double|2x|100% profit|risk[ -]?free|fixed profit|double paisa|paisa double)\b', caseSensitive: false), 'Unrealistic return claim', 'Guaranteed or unusually high financial returns are a common investment-scam indicator.', 27),
    _Rule(RegExp(r'\b(bank|easypaisa|jazzcash|paypal|daraz|courier|police|government|nadra|fia|fbr)\b', caseSensitive: false), 'Possible organization impersonation', 'Verify the request through the organization’s official app, website or trusted phone number.', 8),
    _Rule(RegExp(r'\b(prize|winner|lottery|gift|reward|congratulations|inaam|انعام|لاٹری)\b', caseSensitive: false), 'Unexpected reward', 'Unexpected prizes and rewards are frequently used as scam bait.', 18),
    _Rule(RegExp(r'\b(job offer|work from home|easy income|daily earning|part[ -]?time job|online task|task job)\b', caseSensitive: false), 'Unsolicited earning opportunity', 'Unexpected jobs promising easy income should be independently verified.', 16),
    _Rule(RegExp(r'\b(seed phrase|recovery phrase|private key|wallet key)\b', caseSensitive: false), 'Requests crypto credentials', 'A legitimate service should never ask for your wallet seed phrase or private key.', 38),
    _Rule(RegExp(r'\b(anydesk|teamviewer|remote access|screen share|install this app)\b', caseSensitive: false), 'Requests remote device access', 'Remote-access tools can let a scammer control your phone or computer.', 28),
    _Rule(RegExp(r'(او ٹی پی|پاس ورڈ|پن کوڈ|رقم بھیج|پیسے بھیج|اکاؤنٹ بند|اکاؤنٹ بلاک)'), 'Urdu high-risk phrase', 'The message contains a common Urdu-language scam indicator.', 24),
  ];

  RiskResult analyze(String input) {
    final text = input.trim();
    var score = 0;
    final signals = <RiskSignal>[];

    for (final rule in rules) {
      if (rule.regex.hasMatch(text)) {
        score += rule.points;
        signals.add(RiskSignal(rule.title, rule.detail, rule.points));
      }
    }

    final matches = _url.allMatches(text).toList();
    if (matches.isNotEmpty) {
      final l = text.toLowerCase();
      final risky = l.contains('bit.ly') || l.contains('tinyurl') || l.contains('.xyz') || l.contains('.top') || l.contains('.click');
      final pts = risky ? 24 : 12;
      score += pts;
      signals.add(RiskSignal('Contains a link', risky ? 'The message contains a shortened or unusually risky-looking domain.' : 'Verify the exact domain independently before opening it.', pts));
    }

    score = score.clamp(0, 100);
    final level = score >= 55 ? RiskLevel.high : (score >= 25 ? RiskLevel.medium : RiskLevel.low);
    final lower = text.toLowerCase();
    String category;
    if (lower.contains('seed phrase') || lower.contains('private key') || lower.contains('usdt') || lower.contains('crypto')) {
      category = 'Crypto / investment risk';
    } else if (lower.contains('job') || lower.contains('work from home') || lower.contains('online task')) {
      category = 'Job / task scam risk';
    } else if (lower.contains('bank') || lower.contains('easypaisa') || lower.contains('jazzcash') || lower.contains('otp')) {
      category = 'Financial impersonation / phishing';
    } else if (matches.isNotEmpty) {
      category = 'Phishing / suspicious link';
    } else if (signals.isNotEmpty) {
      category = 'Social-engineering risk';
    } else {
      category = 'No specific scam pattern identified';
    }

    final summary = switch (level) {
      RiskLevel.high => 'Multiple or high-severity scam indicators are present. Treat the message as suspicious until independently verified.',
      RiskLevel.medium => 'Some warning indicators are present. Verify the sender and request before taking action.',
      RiskLevel.low => 'Few common scam indicators were detected, but this does not prove the message is legitimate.',
    };

    final actions = <String>[
      if (level != RiskLevel.low) 'Do not send money, passwords, PINs, OTPs, recovery phrases or identity documents.',
      if (matches.isNotEmpty) 'Do not open the link from the message. Find the organization’s official website or app independently.',
      'Verify the sender using a trusted phone number or official channel.',
      'If money is involved, independently confirm the recipient and purpose before paying.',
    ];

    return RiskResult(text: text, score: score, level: level, category: category, summary: summary, signals: signals, actions: actions);
  }
}
