import 'points.dart';

Map<String, dynamic> cycle({int number = 17, bool current = true}) => {
  'campaignNumber': number,
  'campaignName': 'Vanta campaign $number',
  'description': '',
  'totalVantaPoints': '1000000.000000000000000001',
  'startTime': '2026-10-29T08:00:00+08:00',
  'endTime': '2026-11-05T00:00:00Z',
  'currentCampaign': current,
  'status': 'ACTIVE',
  'orderlyBrokerId': 'vanta_exchange',
};
Map<String, dynamic> ranking({String address = pointsTestAddress, int rank = 1, int? campaign}) => {
  'address': address,
  'rank': rank,
  if (campaign != null) ...{
    'campaignNumber': campaign,
    'points': '12.000000000000000001',
  } else ...{
    'totalPoint': '12.000000000000000001',
    'settledPoints': '9',
    'specialPoints': '2',
    'currentPoint': '1.000000000000000001',
  },
};
