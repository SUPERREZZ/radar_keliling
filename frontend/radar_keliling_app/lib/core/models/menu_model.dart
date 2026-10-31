class MenuPhoto {
  const MenuPhoto({required this.id, required this.url});

  final String id;
  final String url;

  factory MenuPhoto.fromJson(Map<String, dynamic> json) => MenuPhoto(
        id: json['id'] as String,
        url: json['url'] as String,
      );
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.merchantId,
    required this.name,
    this.description,
    required this.price,
    required this.isAvailable,
    required this.photos,
  });

  final String id;
  final String merchantId;
  final String name;
  final String? description;
  final double price;
  final bool isAvailable;
  final List<MenuPhoto> photos;

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'] as String,
        merchantId: json['merchant_id'] as String? ?? '',
        name: json['name'] as String,
        description: json['description'] as String?,
        price: (json['price'] as num).toDouble(),
        isAvailable: json['is_available'] as bool? ?? true,
        photos: (json['photos'] as List<dynamic>? ?? [])
            .map((p) => MenuPhoto.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}
