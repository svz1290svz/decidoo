import 'package:flutter/material.dart';

import '../services/management_api.dart';

class MonetizationHub extends StatefulWidget {
  const MonetizationHub({
    super.key,
    required this.api,
    required this.restaurantId,
    required this.currency,
    required this.countryCode,
  });

  final ManagementApi api;
  final String restaurantId;
  final String currency;
  final String countryCode;

  @override
  State<MonetizationHub> createState() => _MonetizationHubState();
}

class _MonetizationHubState extends State<MonetizationHub> {
  late Future<Map<String, dynamic>> _roi =
      widget.api.monetizationRoi(widget.restaurantId);
  late Future<List<Map<String, dynamic>>> _campaigns =
      widget.api.monetizationCampaigns(widget.restaurantId);
  bool _busy = false;

  Future<void> _reload() async {
    setState(() {
      _roi = widget.api.monetizationRoi(widget.restaurantId);
      _campaigns = widget.api.monetizationCampaigns(widget.restaurantId);
    });
    await Future.wait([_roi, _campaigns]);
  }

  Future<void> _createCampaign(String channel) async {
    final name = TextEditingController(
      text: channel == 'BOOST'
          ? 'Boost kampanyası'
          : channel == 'PER_ACTION'
              ? 'Sonuç bazlı kampanya'
              : 'Akıllı kampanya',
    );
    final budget = TextEditingController(text: '100');
    final bid = TextEditingController(text: channel == 'BOOST' ? '' : '1');
    final radius = TextEditingController(text: '5');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni gelir kampanyası'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Kampanya adı'),
              ),
              TextField(
                controller: budget,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Toplam bütçe (${widget.currency})',
                ),
              ),
              if (channel != 'BOOST')
                TextField(
                  controller: bid,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Aksiyon başı azami ücret (${widget.currency})',
                  ),
                ),
              TextField(
                controller: radius,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Hedef yarıçap (km)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              final parsedBudget = double.tryParse(budget.text.replaceAll(',', '.'));
              final parsedBid = bid.text.trim().isEmpty
                  ? null
                  : double.tryParse(bid.text.replaceAll(',', '.'));
              final parsedRadius =
                  double.tryParse(radius.text.replaceAll(',', '.'));
              if (name.text.trim().length < 2 ||
                  parsedBudget == null ||
                  parsedBudget <= 0 ||
                  parsedRadius == null ||
                  parsedRadius <= 0 ||
                  (channel != 'BOOST' &&
                      (parsedBid == null || parsedBid <= 0))) {
                return;
              }
              setState(() => _busy = true);
              try {
                final now = DateTime.now().toUtc();
                await widget.api.createMonetizationCampaign(
                  restaurantId: widget.restaurantId,
                  name: name.text.trim(),
                  channel: channel,
                  budget: parsedBudget,
                  currency: widget.currency,
                  countryCode: widget.countryCode,
                  startsAt: now,
                  endsAt: now.add(const Duration(days: 30)),
                  targetRadiusKm: parsedRadius,
                  bidPerAction: parsedBid,
                );
                if (context.mounted) Navigator.pop(context, true);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
    name.dispose();
    budget.dispose();
    bid.dispose();
    radius.dispose();
    if (result == true && mounted) await _reload();
  }

  Future<void> _startPro(bool annual) async {
    setState(() => _busy = true);
    try {
      await widget.api.startProSubscription(
        restaurantId: widget.restaurantId,
        annual: annual,
        currency: widget.currency,
        countryCode: widget.countryCode,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pro aboneliği ödeme sağlayıcısına bağlanmak üzere hazırlandı.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Decidoo Gelir Merkezi')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '4 gelir kanalı',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Restoran ücretsiz başlayabilir. Ücretli büyüme araçları ayrı ve ölçülebilir kalır.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            _ChannelCard(
              icon: Icons.rocket_launch_outlined,
              title: '1. Boost',
              body: 'Bütçe ve süre belirle; uygun kullanıcılarda sponsorlu görünürlük kazan.',
              action: 'BOOST OLUŞTUR',
              onPressed: _busy ? null : () => _createCampaign('BOOST'),
            ),
            _ChannelCard(
              icon: Icons.ads_click,
              title: '2. Sonuç bazlı ücret',
              body: 'Restoran açma, navigasyon ve sipariş tıklaması gibi doğrulanmış aksiyonları ölç.',
              action: 'AKSİYON KAMPANYASI',
              onPressed: _busy ? null : () => _createCampaign('PER_ACTION'),
            ),
            _ChannelCard(
              icon: Icons.workspace_premium_outlined,
              title: '3. Decidoo Pro',
              body: 'Gelişmiş analiz ve profesyonel restoran araçları için abonelik altyapısı.',
              action: 'PRO AYLIK',
              secondaryAction: 'PRO YILLIK',
              onPressed: _busy ? null : () => _startPro(false),
              onSecondaryPressed: _busy ? null : () => _startPro(true),
            ),
            _ChannelCard(
              icon: Icons.auto_awesome,
              title: '4. Akıllı kampanyalar',
              body: 'Zaman, mesafe, mutfak ve öğün bağlamına göre bütçeli hedefleme.',
              action: 'AKILLI KAMPANYA',
              onPressed: _busy ? null : () => _createCampaign('SMART_CAMPAIGN'),
            ),
            const SizedBox(height: 18),
            FutureBuilder<Map<String, dynamic>>(
              future: _roi,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                final data = snapshot.data!;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      children: [
                        _Stat(
                          label: 'Doğrulanmış aksiyon',
                          value: '${data['verifiedActions'] ?? 0}',
                        ),
                        _Stat(
                          label: 'Toplam ücret',
                          value: '${data['totalCharged'] ?? 0} ${widget.currency}',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _campaigns,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final campaigns = snapshot.data!;
                if (campaigns.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('Henüz gelir kampanyası oluşturulmadı.'),
                    ),
                  );
                }
                return Column(
                  children: campaigns
                      .map(
                        (item) => ListTile(
                          leading: const Icon(Icons.campaign_outlined),
                          title: Text(item['name']?.toString() ?? 'Kampanya'),
                          subtitle: Text(
                            '${item['channel'] ?? ''} · ${item['status'] ?? ''}',
                          ),
                          trailing: Text(
                            '${item['remainingBudget'] ?? item['budget'] ?? '-'} ${item['currency'] ?? widget.currency}',
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onPressed,
    this.secondaryAction,
    this.onSecondaryPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback? onPressed;
  final String? secondaryAction;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(child: Icon(icon)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(body),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(onPressed: onPressed, child: Text(action)),
                  if (secondaryAction != null)
                    OutlinedButton(
                      onPressed: onSecondaryPressed,
                      child: Text(secondaryAction!),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          Text(label),
        ],
      );
}
