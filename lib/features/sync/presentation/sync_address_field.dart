import 'package:flutter/material.dart';
import 'package:sync_plugin/sync_logic.dart';

String syncAddressOf(LocalSyncState state) =>
    state.localAddress ?? Uri.tryParse(state.endpoint ?? '')?.host ?? '';

class SyncAddressField extends StatefulWidget {
  const SyncAddressField({
    super.key,
    required this.control,
    required this.controller,
    this.enabled = true,
    this.errorText,
    this.onChanged,
  });

  final LocalSyncControl control;
  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  State<SyncAddressField> createState() => _SyncAddressFieldState();
}

class _SyncAddressFieldState extends State<SyncAddressField> {
  List<String> _addresses = const [];

  @override
  void initState() {
    super.initState();
    final control = widget.control;
    final generation = control.generation;
    control.addresses().then((addresses) {
      if (!mounted || control.generation != generation) return;
      setState(() => _addresses = addresses.toSet().toList());
      if (_addresses.isNotEmpty && widget.controller.text.isEmpty) {
        _select(_addresses.first);
      }
    }, onError: (Object _) {});
  }

  void _select(String address) {
    widget.controller.text = address;
    widget.onChanged?.call(address);
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    enabled: widget.enabled,
    onChanged: widget.onChanged,
    decoration: InputDecoration(
      labelText: 'IP этого устройства',
      helperText: 'Адрес Wi-Fi или Ethernet в локальной сети',
      helperMaxLines: 2,
      errorText: widget.errorText,
      errorMaxLines: 3,
      suffixIcon: _addresses.length > 1
          ? PopupMenuButton<String>(
              enabled: widget.enabled,
              tooltip: 'Выбрать локальный IP',
              onSelected: _select,
              itemBuilder: (_) => [
                for (final address in _addresses)
                  PopupMenuItem(value: address, child: Text(address)),
              ],
            )
          : null,
    ),
  );
}
