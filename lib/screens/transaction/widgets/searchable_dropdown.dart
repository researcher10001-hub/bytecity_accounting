import 'package:flutter/material.dart';
import '../../../models/account_model.dart';
import '../../../providers/group_provider.dart';

class SearchableDropdown extends StatefulWidget {
  final Account? value;
  final List<Account> items;
  final String label;
  final ValueChanged<Account?> onChanged;
  final GroupProvider groupProvider;

  const SearchableDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
    required this.groupProvider,
  });

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isOpen = false;
    });
  }

  void _openDropdown() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0.0, size.height + 5.0),
            child: TapRegion(
              onTapOutside: (_) => _closeDropdown(),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                child: _DropdownOverlayContent(
                  items: widget.items,
                  groupProvider: widget.groupProvider,
                  onItemSelected: (item) {
                    widget.onChanged(item);
                    _closeDropdown();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isOpen = true;
    });
  }

  @override
  void dispose() {
    if (_isOpen) {
      _overlayEntry?.remove();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: _toggleDropdown,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            suffixIcon: Icon(
              _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          child: Text(
            widget.value != null
                ? '${widget.value!.name} (${widget.groupProvider.getGroupNames(widget.value!.groupIds)})'
                : 'Select Account',
            style: TextStyle(
              color: widget.value != null
                  ? Colors.black87
                  : Colors.grey.shade600,
              overflow: TextOverflow.ellipsis,
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

class _DropdownOverlayContent extends StatefulWidget {
  final List<Account> items;
  final GroupProvider groupProvider;
  final ValueChanged<Account> onItemSelected;

  const _DropdownOverlayContent({
    required this.items,
    required this.groupProvider,
    required this.onItemSelected,
  });

  @override
  State<_DropdownOverlayContent> createState() =>
      _DropdownOverlayContentState();
}

class _DropdownOverlayContentState extends State<_DropdownOverlayContent> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController =
      ScrollController(); // Add ScrollController
  List<Account> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose(); // Dispose ScrollController
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = widget.items.where((item) {
        return item.name.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sticky Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search...',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
          ),
          const Divider(height: 1),
          // Scrollable List
          Flexible(
            child: _filteredItems.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No results found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : Scrollbar(
                    // Added Scrollbar
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _scrollController,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final groupName = widget.groupProvider.getGroupNames(
                          item.groupIds,
                        );
                        return ListTile(
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '$groupName • ${item.type}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          onTap: () => widget.onItemSelected(item),
                          hoverColor: Colors.blue.withValues(alpha: 0.1),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
