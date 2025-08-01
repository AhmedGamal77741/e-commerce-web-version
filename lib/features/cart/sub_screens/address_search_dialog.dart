import 'package:ecommerece_app/features/cart/services/kakao_service.dart';
import 'package:flutter/material.dart';
import 'dart:async';

final List<String> koreanIslands = [
  '제주도', // Jeju Island :contentReference[oaicite:1]{index=1}
  '우도', // Udo Island off Jeju :contentReference[oaicite:2]{index=2}
  '마라도', // Marado, south of Jeju :contentReference[oaicite:3]{index=3}
  '거제도', // Geoje Island, 2nd largest :contentReference[oaicite:4]{index=4}
  '외도', // Oedo Island botanical garden :contentReference[oaicite:5]{index=5}
  '진도', // Jindo Island & the Miracle Sea Road :contentReference[oaicite:6]{index=6}
  '울릉도', // Ulleungdo in East Sea :contentReference[oaicite:7]{index=7}
  '홍도', // Hongdo Island in Dadohaehaesang NP :contentReference[oaicite:8]{index=8}
  '추자도', // Chuja Islands cluster :contentReference[oaicite:9]{index=9}
  '무의도', // Muuido near Incheon :contentReference[oaicite:10]{index=10}
  '영종도', // Yeongjong‑do (Home to Incheon Airport) :contentReference[oaicite:11]{index=11}
  '소매물도', // Somaemuldo, Tongyeong region :contentReference[oaicite:12]{index=12}
  '비진도', // Bijindo (camping / bioluminescence) :contentReference[oaicite:13]{index=13}
  '욕지도', // Yokjido, small island near Tongyeong :contentReference[oaicite:14]{index=14}
  '사량도', // Saryangdo, hiking island near Tongyeong :contentReference[oaicite:15]{index=15}
  '한산도', // Hansando historic island near Tongyeong :contentReference[oaicite:16]{index=16}
  '미륵도', // Mireukdo connected to Tongyeong by bridge :contentReference[oaicite:17]{index=17}
  '위도', // Wido Island (flower island with European gardens) :contentReference[oaicite:18]{index=18}
  '오륙도', // Oryukdo (Busan offshore islets) :contentReference[oaicite:19]{index=19}
  '거문도', // Geomundo Island :contentReference[oaicite:20]{index=20}
  '덕적도', // Deokjeokdo, Yellow Sea off Incheon :contentReference[oaicite:21]{index=21}
  '소야도', // Soyado, off Deokjeokdo :contentReference[oaicite:22]{index=22}
];

bool likelyIsland(String regionName) {
  final normalized = regionName.replaceAll(RegExp(r'(면|리|도)$'), '');

  return koreanIslands.contains(normalized);
}

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
                    bool isIsland;
                    print(item);
                    final addressData = item['address'] ?? item['road_address'];
                    final region1depth =
                        addressData['region_1depth_name'] as String;
                    final region2depth =
                        addressData['region_2depth_name'] as String;
                    final region3depth =
                        addressData['region_3depth_name'] as String;
                    if (likelyIsland(region1depth) ||
                        likelyIsland(region2depth) ||
                        likelyIsland(region3depth)) {
                      isIsland = true;
                    } else {
                      isIsland = false;
                    }
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
                          if (addressData['mountain_yn'] == 'Y' || isIsland) {
                            // Show message and prevent selection
                            showDialog(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: Text('배송 불가'),
                                    content: Text(
                                      '산간 지역/섬 지역은 배송이 불가합니다. 다른 주소를 선택해 주세요.',
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
