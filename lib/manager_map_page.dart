import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sikendi/mongodb_service.dart';

class ManagerMapPage extends StatefulWidget {
  final LatLng? initialCenter;
  final String? focusDeviceId;

  const ManagerMapPage({super.key, this.initialCenter, this.focusDeviceId});

  @override
  State<ManagerMapPage> createState() => _ManagerMapPageState();
}

class _ManagerMapPageState extends State<ManagerMapPage> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _activeVehicles = [];
  Timer? _timer;

  bool _isTrackingMode = false;
  String? _localFocusId;

  @override
  void initState() {
    super.initState();

    if (widget.focusDeviceId != null) {
      _localFocusId = widget.focusDeviceId;
      _isTrackingMode = true;
    }

    _fetchFleetData();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchFleetData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchFleetData() async {
    final data = await MongoDBService.getFleetDataForManager();

    if (mounted) {
      setState(() {
        _activeVehicles = data;
      });

      if (_isTrackingMode && _localFocusId != null) {
        try {
          final targetCar = _activeVehicles.firstWhere(
            (v) =>
                v['device_id'] == _localFocusId || v['gps_1'] == _localFocusId,
            orElse: () => <String, dynamic>{},
          );

          if (targetCar.isNotEmpty) {
            final LatLng? pos = _parseLocation(targetCar);
            if (pos != null) {
              _mapController.move(pos, 18.0);
            }
          }
        } catch (e) {
          print("Map not ready for move: $e");
        }
      }
    }
  }

  bool _isGpsOffline(String? serverTimeStr) {
    if (serverTimeStr == null) return true;
    try {
      String cleanTime = serverTimeStr.replaceAll('Z', '');
      DateTime lastUpdate = DateTime.parse(cleanTime);
      DateTime now = DateTime.now();
      Duration diff = now.difference(lastUpdate);
      return diff.inMinutes > 5;
    } catch (e) {
      return true;
    }
  }

  Color _getStatusColor(double speed, String? timestamp) {
    if (_isGpsOffline(timestamp)) return Colors.red;
    if (speed > 5) return Colors.green;
    return Colors.orange;
  }

  String _getStatusText(double speed, String? serverTimeStr) {
    if (_isGpsOffline(serverTimeStr)) {
      String cleanTime = serverTimeStr!.replaceAll('Z', '');
      DateTime last = DateTime.parse(cleanTime);
      int minAgo = DateTime.now().difference(last).inMinutes;
      return "GPS Mati / Offline ($minAgo mnt lalu)";
    }
    if (speed > 5) return "Sedang Jalan";
    if (speed > 0) return "Idle";
    return "Parkir";
  }

  LatLng? _parseLocation(Map<String, dynamic> vehicle) {
    try {
      if (vehicle['gps_location'] != null) {
        final loc = vehicle['gps_location'];
        if (loc is Map && loc.containsKey('lat') && loc.containsKey('lng')) {
          return LatLng(
            (loc['lat'] as num).toDouble(),
            (loc['lng'] as num).toDouble(),
          );
        }
        if (loc is Map && loc.containsKey('coordinates')) {
          final List coords = loc['coordinates'];
          if (coords.length >= 2) {
            return LatLng(
              (coords[1] as num).toDouble(),
              (coords[0] as num).toDouble(),
            );
          }
        }
      }
      if (vehicle.containsKey('lat') && vehicle.containsKey('lng')) {
        return LatLng(
          (vehicle['lat'] as num).toDouble(),
          (vehicle['lng'] as num).toDouble(),
        );
      }
    } catch (e) {
      print("Error parsing lokasi untuk ${vehicle['plat']}: $e");
    }
    return null;
  }

  void _showVehicleDetail(BuildContext context, Map<String, dynamic> vehicle) {
    String displayName =
        vehicle['plat'] ??
        vehicle['model'] ??
        vehicle['gps_1'] ??
        vehicle['device_id'] ??
        "Unknown Device";
    String? plat = vehicle['plat'];
    String? model = vehicle['model'];
    String deviceId = vehicle['gps_1'] ?? vehicle['device_id'] ?? "Unknown";

    double speed = (vehicle['speed'] as num? ?? 0).toDouble();
    String? timestamp = vehicle['server_received_at']?.toString();

    LatLng? pos = _parseLocation(vehicle);
    double lat = pos?.latitude ?? 0.0;
    double lng = pos?.longitude ?? 0.0;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.directions_car,
                    size: 30,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (plat != null && model != null)
                          Text(
                            "$model • $plat",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          )
                        else
                          Text(
                            "ID: $deviceId",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(),
              ListTile(
                dense: true,
                leading: const Icon(Icons.speed),
                title: Text("${speed.toStringAsFixed(1)} km/h"),
                subtitle: Text(
                  _getStatusText(speed, timestamp),
                  style: TextStyle(
                    color: _getStatusColor(speed, timestamp),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.access_time),
                title: const Text("Terakhir Update"),
                subtitle: Text(
                  timestamp != null
                      ? DateTime.parse(timestamp.replaceAll('Z', '')).toString().split('.')[0]
                      : "-",
                ),
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.location_on),
                title: const Text("Posisi Koordinat"),
                subtitle: Text(
                  "${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Koordinat disalin!")),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Peta'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: _activeVehicles.isEmpty
          ? const Center(child: Text("Memuat data armada..."))
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: (_isTrackingMode && widget.initialCenter != null)
                    ? widget.initialCenter!
                    : const LatLng(-7.052219, 110.441481),
                initialZoom: (_isTrackingMode && widget.initialCenter != null)
                    ? 18.0
                    : 14.0,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture && _isTrackingMode) {
                    setState(() {
                      _isTrackingMode = false;
                      _localFocusId = null;
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.sikendi.manager',
                ),
                MarkerLayer(
                  markers: _activeVehicles.map((vehicle) {
                    final LatLng? position = _parseLocation(vehicle);
                    if (position == null)
                      return const Marker(
                        point: LatLng(0, 0),
                        child: SizedBox(),
                      );

                    double speed = (vehicle['speed'] as num? ?? 0).toDouble();
                    String? timestamp = vehicle['server_received_at']
                        ?.toString();
                    String label =
                        vehicle['plat'] ??
                        vehicle['model'] ??
                        vehicle['gps_1'] ??
                        "?";

                    bool isFocused =
                        _isTrackingMode &&
                        _localFocusId != null &&
                        (vehicle['gps_1'] == _localFocusId ||
                            vehicle['device_id'] == _localFocusId);

                    return Marker(
                      point: position,
                      width: isFocused ? 80 : 60,
                      height: isFocused ? 80 : 60,
                      child: GestureDetector(
                        onTap: () => _showVehicleDetail(context, vehicle),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isFocused ? Colors.yellow : Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.directions_car_filled,
                              color: _getStatusColor(speed, timestamp),
                              size: isFocused ? 50 : 40,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }
}
