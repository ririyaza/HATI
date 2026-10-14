import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dashboard_screen.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/audio/hati_tap_sound.dart';

class SupportResourcesScreen extends StatelessWidget {
  const SupportResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1E8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Support Resources',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'If you are feeling uncomfortable right now, please contact:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              const _ResourceCard(
                title: 'RAISE Mental Health Hotline (Iloilo City)',
                children: [
                  _ContactRow(
                    icon: Icons.call_rounded,
                    label: 'Contact:',
                    value: '0968-566-3131',
                    kind: _ContactKind.phone,
                  ),
                  _ContactRow(
                    icon: Icons.email_rounded,
                    label: 'Email:',
                    value: 'raisementalhealth.iloph@gmail.com',
                    kind: _ContactKind.email,
                  ),
                  _ContactRow(
                    icon: Icons.schedule_rounded,
                    label: 'Availability:',
                    value: 'Monday to Friday, 8 a.m. to 4 p.m.',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _ResourceCard(
                title:
                    'Western Visayas Medical Center (WVMC) Crisis Hotlines:',
                children: [
                  _ContactRow(
                    icon: Icons.call_rounded,
                    label: 'Mandurriao Psychiatry Dept:',
                    value: '0931-025-1276',
                    kind: _ContactKind.phone,
                  ),
                  _ContactRow(
                    icon: Icons.call_rounded,
                    label: 'Pototan Mental Health Unit:',
                    value: '0912-091-1461',
                    kind: _ContactKind.phone,
                  ),
                  _ContactRow(
                    icon: Icons.call_rounded,
                    label: 'La Paz Psychiatry Dept:',
                    value: '0906-457-1619',
                    kind: _ContactKind.phone,
                  ),
                  _ContactRow(
                    icon: Icons.email_rounded,
                    label: 'Email:',
                    value: 'psychdepartment2016@gmail.com',
                    kind: _ContactKind.email,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _ResourceCard(
                title: 'University Guidance Center',
                children: [
                  _StaffGroup(
                    officeLabel: 'CICT',
                    name: 'Maybelle P. de la Gente, MEd, RGC, JD',
                    email: 'univ-guidance@wvsu.edu.ph',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _ResourceCard(
                title: 'Prime Helpline',
                children: [
                  _ContactRow(
                    icon: Icons.email_rounded,
                    label: 'Email:',
                    value: 'prime.iloilo1@gmail.com',
                    kind: _ContactKind.email,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _ResourceCard(
                title: 'Iloilo City Emergency Response (ICER)',
                children: [
                  _ContactRow(
                    icon: Icons.call_rounded,
                    label: 'Contact:',
                    value: '09190661554',
                    kind: _ContactKind.phone,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    backgroundColor: const Color(0xFFF5F1E8),
                  ),
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                    (route) => false,
                  ),
                  child: const Text(
                    'Return Home',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.creamLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF0B28D9),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              title,
              style: const TextStyle(
                color: const Color(0xFFF5F1E8),
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ContactKind {
  /// Plain info row (e.g. "Availability:", "Name:") — not tappable.
  none,
  phone,
  email,
}

class _ContactRow extends StatefulWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.kind = _ContactKind.none,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Phone/email rows: tapping the row opens the dialer/mail app with
  /// [value] pre-filled; a separate small copy icon lets the user copy it
  /// instead, for anyone who'd rather save it than act on it right away.
  /// `none` rows (like "Availability:"/"Name:") are plain, non-interactive
  /// text.
  final _ContactKind kind;

  @override
  State<_ContactRow> createState() => _ContactRowState();
}

class _ContactRowState extends State<_ContactRow> {
  bool _justCopied = false;

  bool get _actionable => widget.kind != _ContactKind.none;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    setState(() => _justCopied = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${widget.label.replaceAll(':', '')} copied'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _justCopied = false);
    });
  }

  Future<void> _launch() async {
    final uri = switch (widget.kind) {
      _ContactKind.phone => Uri(
        scheme: 'tel',
        path: widget.value.replaceAll(RegExp(r'[^0-9+]'), ''),
      ),
      _ContactKind.email => Uri(scheme: 'mailto', path: widget.value.trim()),
      _ContactKind.none => null,
    };
    if (uri == null) return;
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } catch (_) {
      // Fall through to the copy fallback below.
    }
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            "Couldn't open — ${widget.label.replaceAll(':', '')} copied instead",
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(widget.icon, size: 16, color: const Color(0xFF0B28D9)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Colors.black87,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '${widget.label} ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: widget.value,
                    style: _actionable
                        ? const TextStyle(
                            color: Color(0xFF0B28D9),
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFF0B28D9),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
          if (_actionable) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: _copy,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(
                  _justCopied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 15,
                  color: _justCopied
                      ? const Color(0xFF2D5A27)
                      : Colors.black38,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (!_actionable) return row;

    return HatiTapSound.click(
      child: InkWell(
        onTap: _launch,
        borderRadius: BorderRadius.circular(6),
        child: row,
      ),
    );
  }
}

class _StaffGroup extends StatelessWidget {
  const _StaffGroup({
    required this.officeLabel,
    required this.name,
    this.phone,
    this.email,
  });

  final String officeLabel;
  final String name;
  final String? phone;
  final String? email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          officeLabel,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        _ContactRow(icon: Icons.person_rounded, label: 'Name:', value: name),
        if (phone != null)
          _ContactRow(
            icon: Icons.call_rounded,
            label: 'Phone:',
            value: phone!,
            kind: _ContactKind.phone,
          ),
        if (email != null)
          _ContactRow(
            icon: Icons.email_rounded,
            label: 'Email:',
            value: email!,
            kind: _ContactKind.email,
          ),
      ],
    );
  }
}
