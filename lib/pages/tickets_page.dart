import 'package:flutter/material.dart';

class TicketsPage extends StatelessWidget {
  const TicketsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Replace with your real tickets list / API later
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: () {
            // TODO: push create-ticket form
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('New ticket coming soon…')));
          },
          icon: const Icon(Icons.add),
          label: const Text('Create Ticket'),
        ),
        const SizedBox(height: 16),
        const _TicketCard(
          title: 'Sign missing at XYZ',
          id: 'TCK-111',
          status: 'Open',
          subtitle: 'Reported by field crew • 2025-09-20',
        ),
        const _TicketCard(
          title: 'Damaged curb at XYZ.',
          id: 'TCK-222',
          status: 'In Progress',
          subtitle: 'Reported by field crew • 2025-09-20',
        ),
        const _TicketCard(
          title: 'Drainage clog at XYZ.',
          id: 'TCK-333',
          status: 'Closed',
          subtitle: 'Resolved • 2025-09-20',
        ),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.title,
    required this.id,
    required this.status,
    required this.subtitle,
  });

  final String title;
  final String id;
  final String status;
  final String subtitle;

  Color _chipColor(BuildContext ctx) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.red;
      case 'in progress':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Chip(
          label: Text(status),
          backgroundColor: _chipColor(context).withOpacity(0.15),
          labelStyle: TextStyle(color: _chipColor(context)),
        ),
        onTap: () {
          // TODO: open ticket detail
        },
      ),
    );
  }
}
