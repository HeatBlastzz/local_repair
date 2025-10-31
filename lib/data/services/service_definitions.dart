class ServiceDefinition {
  final String id;
  final String name;
  final String iconAsset;

  const ServiceDefinition({
    required this.id,
    required this.name,
    required this.iconAsset,
  });
}

final List<ServiceDefinition> serviceDefinitions = [
  const ServiceDefinition(
    id: 'locksmith',
    name: 'Sửa khóa',
    iconAsset: 'assets/imgs/locksmith.jpg',
  ),
  const ServiceDefinition(
    id: 'plumbing',
    name: 'Sửa ống nước',
    iconAsset: 'assets/imgs/water.jpg',
  ),
  const ServiceDefinition(
    id: 'refrigeration',
    name: 'Sửa điện lạnh',
    iconAsset: 'assets/imgs/refrigeration.jpg',
  ),
  const ServiceDefinition(
    id: 'kitchen_repair',
    name: 'Sửa chữa bếp',
    iconAsset: 'assets/imgs/kitchen.jpg',
  ),
];
