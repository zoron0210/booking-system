class SocialClub {
  const SocialClub({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerUserId,
    required this.ownerName,
    required this.logoUrl,
    required this.memberCount,
    required this.isOwner,
    required this.isMember,
    required this.isPending,
    required this.requiresJoinApproval,
  });

  final int id;
  final String name;
  final String? description;
  final int ownerUserId;
  final String ownerName;
  final String? logoUrl;
  final int memberCount;
  final bool isOwner;
  final bool isMember;
  final bool isPending;
  final bool requiresJoinApproval;

  factory SocialClub.fromJson(Map<String, dynamic> json) => SocialClub(
    id: _int(json['id']),
    name: json['name'] is String ? json['name'] as String : '',
    description: json['description'] as String?,
    ownerUserId: _int(json['ownerUserId']),
    ownerName:
        json['ownerName'] is String &&
            (json['ownerName'] as String).trim().isNotEmpty
        ? (json['ownerName'] as String).trim()
        : 'SpotGo user',
    logoUrl: json['logoUrl'] is String ? json['logoUrl'] as String : null,
    memberCount: _int(json['memberCount']),
    isOwner: json['isOwner'] == true || json['isOwner'] == 1,
    isMember: json['isMember'] == true || json['isMember'] == 1,
    isPending: json['isPending'] == true || json['isPending'] == 1,
    requiresJoinApproval:
        json['requiresJoinApproval'] == true ||
        json['requiresJoinApproval'] == 1,
  );
}

int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
