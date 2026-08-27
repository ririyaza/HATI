import 'package:flutter/material.dart';

import 'dashboard_screen.dart';

class SupportResourcesScreen extends StatelessWidget {
  const SupportResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                  ),
                  _ContactRow(
                    icon: Icons.call_rounded,
                    label: 'Pototan Mental Health Unit:',
                    value: '0912-091-1461',
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
                    phone: '09xx-xxx-xxxx',
                  ),
                  SizedBox(height: 12),
                  _StaffGroup(
                    officeLabel: 'UTC',
                    name: 'Windy de la Cruz, RPm, RPsy',
                    phone: '09xx-xxx-xxxx',
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
                    backgroundColor: Colors.white,
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
        border: Border.all(color: const Color(0xFFE0E0E0)),
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
                color: Colors.white,
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

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0B28D9)),
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
                    text: '$label ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffGroup extends StatelessWidget {
  const _StaffGroup({
    required this.officeLabel,
    required this.name,
    required this.phone,
  });

  final String officeLabel;
  final String name;
  final String phone;

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
        _ContactRow(icon: Icons.call_rounded, label: 'Phone:', value: phone),
      ],
    );
  }
}
