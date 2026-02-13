import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../models/account_model.dart';
import '../../../providers/group_provider.dart';

class AccountAutocomplete extends StatefulWidget {
  final List<Account> options;
  final Account? initialValue;
  final String label;
  final ValueChanged<Account> onSelected;
  final GroupProvider groupProvider;

  const AccountAutocomplete({
    super.key,
    required this.options,
    required this.onSelected,
    required this.groupProvider,
    this.initialValue,
    this.label = 'Account',
  });

  @override
  State<AccountAutocomplete> createState() => _AccountAutocompleteState();
}

class _AccountAutocompleteState extends State<AccountAutocomplete> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue?.name ?? '');
  }

  @override
  void didUpdateWidget(AccountAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      if (widget.initialValue != null) {
        // Only update text if it's different to avoid cursor jumping if we were editing
        // But here initialValue usually comes from parent selection.
        // If parent sets null, we clear.
        if (_controller.text != widget.initialValue!.name) {
          _controller.text = widget.initialValue!.name;
        }
      } else {
        _controller.clear();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<Account>(
      controller: _controller,
      builder: (context, controller, focusNode) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
          decoration: InputDecoration(
            labelText: widget.label.toUpperCase(),
            labelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF718096),
              letterSpacing: 0.5,
            ),
            hintText: 'Search for account...',
            hintStyle: const TextStyle(color: Color(0xFFA0AEC0), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF7FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF4299E1),
                width: 1.5,
              ),
            ),
            prefixIcon: const Icon(
              LucideIcons.search,
              size: 18,
              color: Color(0xFF718096),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      LucideIcons.x,
                      size: 16,
                      color: Color(0xFF718096),
                    ),
                    onPressed: () => controller.clear(),
                  )
                : null,
          ),
        );
      },
      suggestionsCallback: (pattern) {
        if (pattern.isEmpty) {
          return widget.options; // Show all on empty
        }
        return widget.options
            .where(
              (account) =>
                  account.name.toLowerCase().contains(pattern.toLowerCase()),
            )
            .toList();
      },
      itemBuilder: (context, account) {
        final groupName = widget.groupProvider.getGroupNames(account.groupIds);
        return ListTile(
          dense: true,
          title: Text(
            account.name,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            '$groupName • ${account.type}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        );
      },
      onSelected: (account) {
        _controller.text = account.name;
        widget.onSelected(account);
      },
      hideOnUnfocus: true,
      hideOnSelect: true,
      hideOnEmpty: true,
      hideOnLoading: false,
      autoFlipDirection: true,
      emptyBuilder: (context) => const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No accounts found', style: TextStyle(color: Colors.grey)),
      ),
      decorationBuilder: (context, child) {
        return Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
          child: child,
        );
      },
      offset: const Offset(0, 5),
      constraints: const BoxConstraints(maxHeight: 350),
      animationDuration: const Duration(milliseconds: 200),
    );
  }
}
