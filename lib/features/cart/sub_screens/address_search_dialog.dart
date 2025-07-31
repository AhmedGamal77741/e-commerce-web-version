import 'package:ecommerece_app/features/cart/services/kakao_service.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class AddressSearchDialog extends StatefulWidget {
  final KakaoApiService kakaoService;

  const AddressSearchDialog({Key? key, required this.kakaoService})
    : super(key: key);

  @override
  State<AddressSearchDialog> createState() => _AddressSearchDialogState();
}

class _AddressSearchDialogState extends State<AddressSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.kakaoService.searchAddress(query);

      setState(() {
        _searchResults = result['documents'] as List;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '주소를 검색하는 중 오류가 발생했습니다.';
        _isLoading = false;
      });
      print('Error searching address: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      '주소 검색',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '도로명, 지번, 건물명으로 검색',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  suffixIcon:
                      _searchController.text.isNotEmpty
                          ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[600]),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = [];
                              });
                            },
                          )
                          : null,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _performSearch,
                autofocus: true,
              ),
            ),

            // Loading indicator
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: CircularProgressIndicator(color: Colors.grey[800]),
              )
            // Error message
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            // Empty state
            else if (_searchResults.isEmpty &&
                _searchController.text.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('검색 결과가 없습니다. 다른 주소를 입력해 보세요.'),
              )
            // Results list
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _searchResults.length,
                  separatorBuilder:
                      (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _searchResults[index];
                    final addressName = item['address_name'] as String;

                    // Get road address or regular address details
                    final addressDetail =
                        item['road_address'] != null
                            ? '${item['road_address']['address_name']}'
                            : item['address'] != null
                            ? '지번: ${item['address']['main_address_no']}${item['address']['sub_address_no'] != '' ? '-${item['address']['sub_address_no']}' : ''}'
                            : '';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      title: Text(
                        addressName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle:
                          addressDetail.isNotEmpty
                              ? Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  addressDetail,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              )
                              : null,
                      onTap: () {
                        final addressData =
                            item['address'] ?? item['road_address'];
                        if (addressData != null &&
                            addressData['mountain_yn'] != null) {
                          if (addressData['mountain_yn'] == 'Y') {
                            // Show message and prevent selection
                            showDialog(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: Text('배송 불가'),
                                    content: Text(
                                      '해당 산간지역은 배송이 불가합니다. 다른 주소를 선택해주세요.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.of(context).pop(),
                                        child: Text('확인'),
                                      ),
                                    ],
                                  ),
                            );
                            return;
                          }
                        }
                        Navigator.of(context).pop(item);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
