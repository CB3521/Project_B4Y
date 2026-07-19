import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';

class KakaoMapPolyline {
  const KakaoMapPolyline({
    required this.points,
    required this.color,
    this.strokeWidth = 5,
  });

  final List<LatLng> points;
  final Color color;
  final double strokeWidth;

  Map<String, Object?> toJson() {
    return {
      'points': [
        for (final point in points)
          {'lat': point.latitude, 'lng': point.longitude},
      ],
      'color': _cssHex(color),
      'strokeWidth': strokeWidth,
    };
  }
}

class KakaoMapMarker {
  const KakaoMapMarker({
    required this.id,
    required this.point,
    required this.kind,
    this.title,
    this.arrow,
    this.imageUrl,
    this.accentColor,
  });

  final String id;
  final LatLng point;
  final String kind;
  final String? title;
  final String? arrow;
  final String? imageUrl;
  final Color? accentColor;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'lat': point.latitude,
      'lng': point.longitude,
      'kind': kind,
      'title': title,
      'arrow': arrow,
      'imageUrl': imageUrl,
      'accentColor': accentColor == null ? null : _cssHex(accentColor!),
    };
  }
}

class KakaoMapView extends StatefulWidget {
  const KakaoMapView({
    super.key,
    required this.apiKey,
    required this.center,
    required this.zoom,
    required this.markers,
    this.polylines = const [],
    this.interactive = true,
    this.fitToContent = false,
    this.fitPoints = const [],
    this.fitCenter,
    this.onMarkerTap,
    this.onCenterChanged,
    required this.fallback,
  });

  final String apiKey;
  final LatLng center;
  final int zoom;
  final List<KakaoMapMarker> markers;
  final List<KakaoMapPolyline> polylines;
  final bool interactive;
  final bool fitToContent;
  final List<LatLng> fitPoints;
  final LatLng? fitCenter;
  final ValueChanged<String>? onMarkerTap;
  final ValueChanged<LatLng>? onCenterChanged;
  final Widget fallback;

  @override
  State<KakaoMapView> createState() => _KakaoMapViewState();
}

class _KakaoMapViewState extends State<KakaoMapView> {
  WebViewController? _controller;
  String? _loadedHtml;
  String? _lastPayload;

  @override
  void initState() {
    super.initState();
    _configureController();
  }

  @override
  void didUpdateWidget(covariant KakaoMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null) {
      _configureController();
      return;
    }
    if (widget.apiKey != oldWidget.apiKey) {
      _loadHtmlIfNeeded();
    } else {
      _updateMapIfNeeded();
    }
  }

  void _configureController() {
    if (widget.apiKey.trim().isEmpty) {
      return;
    }
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel(
          'B4YMap',
          onMessageReceived: (message) {
            _handleMapMessage(message.message);
          },
        );
      _controller = controller;
      _loadHtmlIfNeeded();
    } on Object {
      _controller = null;
    }
  }

  void _handleMapMessage(String message) {
    try {
      final decoded = jsonDecode(message);
      if (decoded is Map<String, dynamic> &&
          decoded['type'] == 'centerChanged') {
        final lat = decoded['lat'];
        final lng = decoded['lng'];
        if (lat is num && lng is num) {
          widget.onCenterChanged?.call(LatLng(lat.toDouble(), lng.toDouble()));
        }
        return;
      }
    } on Object {
      // Plain marker ids from older map payloads are handled below.
    }
    widget.onMarkerTap?.call(message);
  }

  void _loadHtmlIfNeeded() {
    final controller = _controller;
    if (controller == null || widget.apiKey.trim().isEmpty) {
      return;
    }
    final html = _buildHtml();
    if (html == _loadedHtml) {
      return;
    }
    _loadedHtml = html;
    _lastPayload = _buildPayloadJson();
    controller.loadHtmlString(html, baseUrl: 'https://localhost');
  }

  void _updateMapIfNeeded() {
    final controller = _controller;
    if (controller == null || _loadedHtml == null) return;
    final payload = _buildPayloadJson();
    if (payload == _lastPayload) return;
    _lastPayload = payload;
    unawaited(controller.runJavaScript('window.b4yMapRender($payload);'));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || widget.apiKey.trim().isEmpty) {
      return widget.fallback;
    }
    return WebViewWidget(controller: controller);
  }

  String _buildHtml() {
    final payload = _buildPayloadJson();
    final appKey = Uri.encodeComponent(widget.apiKey.trim());
    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    html, body, #map { width: 100%; height: 100%; margin: 0; padding: 0; overflow: hidden; }
    body { background: #eef1f4; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    .overlay { --stack-offset: 0px; position: relative; display: flex; flex-direction: column; align-items: center; transform: translateY(-6px); }
    .current-location-overlay { transform: none; }
    .label { max-width: 184px; padding: 4px 7px; border-radius: 7px; background: #fff; color: #1f2937; font-size: 11px; font-weight: 700; line-height: 1.2; text-align: center; box-shadow: 0 2px 7px rgba(15, 23, 42, .22); border: 1px solid rgba(15, 23, 42, .12); word-break: keep-all; transform: translateY(calc(-1 * var(--stack-offset))); }
    .dot { width: 14px; height: 14px; margin-top: 3px; border-radius: 999px; background: var(--accent); border: 2px solid #fff; box-shadow: 0 1px 4px rgba(15, 23, 42, .28); }
    .thumb-label { display: flex; align-items: center; gap: 6px; max-width: 190px; padding: 4px; border-radius: 8px; background: #fff; border: 2px solid var(--accent); box-shadow: 0 2px 8px rgba(15, 23, 42, .25); color: #111827; font-size: 11px; font-weight: 800; line-height: 1.2; transform: translateY(calc(-1 * var(--stack-offset))); }
    .thumb-label span { min-width: 0; max-width: 138px; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; word-break: keep-all; }
    .thumb-label img { width: 34px; height: 34px; border-radius: 6px; object-fit: cover; flex: 0 0 auto; }
    .photo-box { width: 42px; height: 42px; overflow: hidden; border-radius: 8px; border: 2px solid var(--accent); background: #fff; box-shadow: 0 2px 8px rgba(15, 23, 42, .25); }
    .photo-box img { width: 100%; height: 100%; object-fit: cover; }
    .circle-photo { width: 42px; height: 42px; overflow: hidden; border-radius: 999px; border: 3px solid var(--accent); background: #fff; box-shadow: 0 2px 8px rgba(15, 23, 42, .25); }
    .circle-photo img { width: 100%; height: 100%; object-fit: cover; }
    .mission { max-width: 136px; padding: 7px 9px; border-radius: 8px; background: #e6f2d8; border: 2px solid var(--accent); color: #18310d; font-size: 11px; font-weight: 800; line-height: 1.25; box-shadow: 0 2px 8px rgba(15, 23, 42, .25); transform: translateY(calc(-1 * var(--stack-offset))); }
    .mission-tip { width: 0; height: 0; border-left: 9px solid transparent; border-right: 9px solid transparent; border-top: 12px solid var(--accent); }
    .spot-pointer { width: 26px; height: 34px; position: relative; }
    .spot-pointer::before { content: ''; position: absolute; left: 3px; top: 0; width: 20px; height: 20px; border-radius: 50% 50% 50% 0; background: var(--accent); transform: rotate(-45deg); box-shadow: 0 2px 5px rgba(15, 23, 42, .28); }
    .spot-pointer span { position: absolute; left: 10px; top: 7px; width: 6px; height: 6px; border-radius: 50%; background: #fff; z-index: 1; }
    .current-location { width: 20px; height: 20px; border: 3px solid #fff; border-radius: 50%; background: #167a72; box-shadow: 0 1px 6px rgba(15, 23, 42, .4); }
    button.overlay { padding: 0; border: 0; background: transparent; cursor: pointer; }
  </style>
  <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=$appKey&autoload=false"></script>
</head>
<body>
  <div id="map"></div>
  <script>
    const data = $payload;
    const esc = (value) => String(value || '').replace(/[&<>"']/g, (ch) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;', "'": '&#39;'}[ch]));
    const sendTap = (id) => {
      if (window.B4YMap && id) {
        window.B4YMap.postMessage(id);
      }
    };
    const overlaps = (a, b) => (
      a.left < b.right + 4 &&
      a.right > b.left - 4 &&
      a.top < b.bottom + 4 &&
      a.bottom > b.top - 4
    );
    const arrangeTextOverlays = () => {
      const labels = Array.from(document.querySelectorAll('#map .label, #map .thumb-label, #map .mission'));
      labels.forEach((label) => label.closest('.overlay').style.setProperty('--stack-offset', '0px'));
      labels.sort((a, b) => b.getBoundingClientRect().bottom - a.getBoundingClientRect().bottom);
      const placed = [];
      labels.forEach((label) => {
        const overlay = label.closest('.overlay');
        let offset = 0;
        for (let attempt = 0; attempt < 20; attempt += 1) {
          const rect = label.getBoundingClientRect();
          const collision = placed.find((placedRect) => overlaps(rect, placedRect));
          if (!collision) {
            placed.push(rect);
            return;
          }
          offset += Math.max(12, Math.ceil(rect.bottom - collision.top + 6));
          overlay.style.setProperty('--stack-offset', offset + 'px');
        }
        placed.push(label.getBoundingClientRect());
      });
    };
    const scheduleTextOverlayLayout = () => {
      requestAnimationFrame(() => requestAnimationFrame(arrangeTextOverlays));
      setTimeout(arrangeTextOverlays, 250);
    };
    const markerHtml = (marker) => {
      const accent = marker.accentColor || '#2f6f3e';
      const title = esc(marker.title);
      const image = marker.imageUrl ? '<img src="' + esc(marker.imageUrl) + '" alt="">' : '';
      let inner = '';
      if (marker.kind === 'spotStop') {
        inner = '<div class="thumb-label">' + image + '<span>' + title + '</span></div><div class="dot"></div>';
      } else if (marker.kind === 'photo') {
        inner = '<div class="photo-box">' + image + '</div>';
      } else if (marker.kind === 'spot') {
        inner = '<div class="circle-photo">' + image + '</div>';
      } else if (marker.kind === 'mission') {
        inner = '<div class="mission">⚑ ' + title + '</div><div class="mission-tip"></div>';
      } else if (marker.kind === 'detailSpot') {
        inner = '<div class="spot-pointer"><span></span></div>';
      } else if (marker.kind === 'selectedLocation') {
        inner = '<div class="label nearest-label">' + title + '</div><div class="spot-pointer"><span></span></div>';
      } else if (marker.kind === 'currentLocation') {
        inner = '<div class="current-location"><span></span></div>';
      } else if (marker.kind === 'nearestStop' || marker.kind === 'boardingStop') {
        inner = '<div class="label nearest-label">' + title + '</div><div class="dot nearest-dot"></div>';
      } else {
        inner = '<div class="dot"></div>';
      }
      const tag = marker.id ? 'button' : 'div';
      const overlayClass = marker.kind === 'currentLocation'
        ? 'overlay current-location-overlay'
        : 'overlay';
      return '<' + tag + ' class="' + overlayClass + '" style="--accent:' + accent + '" onclick="sendTap(\\'' + esc(marker.id) + '\\')">' + inner + '</' + tag + '>';
    };
    kakao.maps.load(() => {
      const map = new kakao.maps.Map(document.getElementById('map'), {
        center: new kakao.maps.LatLng(data.center.lat, data.center.lng),
        level: data.zoom
      });
      const sendCenter = () => {
        if (window.B4YMap) {
          const currentCenter = map.getCenter();
          window.B4YMap.postMessage(JSON.stringify({
            type: 'centerChanged',
            lat: currentCenter.getLat(),
            lng: currentCenter.getLng()
          }));
        }
      };
      if (!data.interactive) {
        map.setDraggable(false);
        map.setZoomable(false);
      }
      if (data.interactive) {
        kakao.maps.event.addListener(map, 'dragend', sendCenter);
        kakao.maps.event.addListener(map, 'zoom_changed', sendCenter);
      }
      window.b4yMapOverlays = [];
      window.b4yMapRender = (next) => {
        window.b4yMapOverlays.forEach((overlay) => overlay.setMap(null));
        window.b4yMapOverlays = [];
        map.setLevel(next.zoom);
        next.polylines.forEach((line) => {
          window.b4yMapOverlays.push(new kakao.maps.Polyline({
            map,
            path: line.points.map((point) => new kakao.maps.LatLng(point.lat, point.lng)),
            strokeWeight: line.strokeWidth,
            strokeColor: line.color,
            strokeOpacity: 0.9,
            strokeStyle: 'solid'
          }));
        });
        next.markers.forEach((marker) => {
          window.b4yMapOverlays.push(new kakao.maps.CustomOverlay({
            map,
            position: new kakao.maps.LatLng(marker.lat, marker.lng),
            content: markerHtml(marker),
            xAnchor: 0.5,
            yAnchor: marker.kind === 'currentLocation' ? 0.5 : 1
          }));
        });
        scheduleTextOverlayLayout();
        document.querySelectorAll('#map .overlay img').forEach((image) => {
          image.addEventListener('load', scheduleTextOverlayLayout, { once: true });
        });
        const fitMap = () => {
          map.relayout();
          const bounds = new kakao.maps.LatLngBounds();
          let hasPoint = false;
          const fitPoints = next.fitPoints.length > 0
            ? next.fitPoints
            : [
                ...next.polylines.flatMap((line) => line.points),
                ...next.markers.map((marker) => marker)
              ];
          fitPoints.forEach((point) => {
            bounds.extend(new kakao.maps.LatLng(point.lat, point.lng));
            hasPoint = true;
            if (next.fitCenter) {
              bounds.extend(new kakao.maps.LatLng(
                (2 * next.fitCenter.lat) - point.lat,
                (2 * next.fitCenter.lng) - point.lng
              ));
            }
          });
          if (hasPoint && next.fitToContent) {
            map.setBounds(bounds, 48, 56, 48, 56);
            if (map.getLevel() < next.zoom) map.setLevel(next.zoom);
            if (next.fitCenter) {
              map.setCenter(new kakao.maps.LatLng(
                next.fitCenter.lat,
                next.fitCenter.lng
              ));
            }
          } else {
            map.setCenter(new kakao.maps.LatLng(
              next.center.lat,
              next.center.lng
            ));
          }
        };
        requestAnimationFrame(fitMap);
        setTimeout(fitMap, 100);
      };
      window.b4yMapRender(data);
      kakao.maps.event.addListener(map, 'idle', scheduleTextOverlayLayout);
    });
  </script>
</body>
</html>
''';
  }

  String _buildPayloadJson() => jsonEncode({
    'center': {'lat': widget.center.latitude, 'lng': widget.center.longitude},
    'zoom': widget.zoom,
    'interactive': widget.interactive,
    'fitToContent': widget.fitToContent,
    'fitPoints': [
      for (final point in widget.fitPoints)
        {'lat': point.latitude, 'lng': point.longitude},
    ],
    'fitCenter': widget.fitCenter == null
        ? null
        : {
            'lat': widget.fitCenter!.latitude,
            'lng': widget.fitCenter!.longitude,
          },
    'markers': widget.markers.map((marker) => marker.toJson()).toList(),
    'polylines': widget.polylines.map((polyline) => polyline.toJson()).toList(),
  });
  /*
    final appKey = Uri.encodeComponent(widget.apiKey.trim());
    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    html, body, #map { width: 100%; height: 100%; margin: 0; padding: 0; overflow: hidden; }
    body { background: #eef1f4; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    .overlay { --stack-offset: 0px; position: relative; display: flex; flex-direction: column; align-items: center; transform: translateY(-6px); }
    .current-location-overlay { transform: none; }
    .label { max-width: 184px; padding: 4px 7px; border-radius: 7px; background: #fff; color: #1f2937; font-size: 11px; font-weight: 700; line-height: 1.2; text-align: center; box-shadow: 0 2px 7px rgba(15, 23, 42, .22); border: 1px solid rgba(15, 23, 42, .12); word-break: keep-all; transform: translateY(calc(-1 * var(--stack-offset))); }
    .dot { width: 14px; height: 14px; margin-top: 3px; border-radius: 999px; background: var(--accent); border: 2px solid #fff; box-shadow: 0 1px 4px rgba(15, 23, 42, .28); }
    .thumb-label { display: flex; align-items: center; gap: 6px; max-width: 190px; padding: 4px; border-radius: 8px; background: #fff; border: 2px solid var(--accent); box-shadow: 0 2px 8px rgba(15, 23, 42, .25); color: #111827; font-size: 11px; font-weight: 800; line-height: 1.2; transform: translateY(calc(-1 * var(--stack-offset))); }
    .thumb-label span { min-width: 0; max-width: 138px; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; word-break: keep-all; }
    .thumb-label img { width: 34px; height: 34px; border-radius: 6px; object-fit: cover; flex: 0 0 auto; }
    .arrow { color: var(--accent); font-size: 22px; line-height: 1; font-weight: 900; text-shadow: 0 1px 2px #fff; }
    .circle-photo { width: 62px; height: 62px; padding: 4px; border-radius: 999px; background: #fff; border: 2px solid var(--accent); box-shadow: 0 2px 7px rgba(15, 23, 42, .24); }
    .circle-photo img { width: 100%; height: 100%; border-radius: 999px; object-fit: cover; }
    .photo-box { width: 54px; height: 54px; padding: 3px; border-radius: 6px; background: #fff; border: 1px solid var(--accent); box-shadow: 0 2px 7px rgba(15, 23, 42, .20); }
    .photo-box img { width: 100%; height: 100%; border-radius: 4px; object-fit: cover; }
    .mission { max-width: 136px; padding: 7px 9px; border-radius: 8px; background: #e6f2d8; border: 2px solid var(--accent); color: #18310d; font-size: 11px; font-weight: 800; line-height: 1.25; box-shadow: 0 2px 8px rgba(15, 23, 42, .25); transform: translateY(calc(-1 * var(--stack-offset))); }
    .mission-tip { width: 0; height: 0; border-left: 9px solid transparent; border-right: 9px solid transparent; border-top: 12px solid var(--accent); }
    .spot-pointer { width: 22px; height: 22px; transform: rotate(45deg); border-radius: 14px 14px 2px 14px; background: var(--accent); border: 2px solid #fff; box-shadow: 0 2px 7px rgba(15, 23, 42, .32); display: grid; place-items: center; }
    .spot-pointer span { width: 8px; height: 8px; border-radius: 999px; background: #fff; opacity: .92; }
    .current-location { width: 24px; height: 24px; border-radius: 999px; background: rgba(37, 99, 235, .18); border: 2px solid rgba(37, 99, 235, .38); display: grid; place-items: center; box-shadow: 0 2px 8px rgba(15, 23, 42, .25); }
    .current-location span { width: 12px; height: 12px; border-radius: 999px; background: #2563eb; border: 2px solid #fff; }
    .nearest-label { border-color: var(--accent); font-weight: 800; }
    .nearest-dot { width: 16px; height: 16px; }
    button.overlay { border: 0; background: transparent; padding: 0; cursor: pointer; }
  </style>
  <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=$appKey&autoload=false"></script>
</head>
<body>
  <div id="map"></div>
  <script>
    const data = $payload;
    const esc = (value) => String(value || '').replace(/[&<>"']/g, (ch) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;', "'": '&#39;'}[ch]));
    const sendTap = (id) => {
      if (window.B4YMap && id) {
        window.B4YMap.postMessage(id);
      }
    };
    const overlaps = (a, b) => (
      a.left < b.right + 4 &&
      a.right > b.left - 4 &&
      a.top < b.bottom + 4 &&
      a.bottom > b.top - 4
    );
    const arrangeTextOverlays = () => {
      const labels = Array.from(document.querySelectorAll('#map .label, #map .thumb-label, #map .mission'));
      labels.forEach((label) => label.closest('.overlay').style.setProperty('--stack-offset', '0px'));
      labels.sort((a, b) => b.getBoundingClientRect().bottom - a.getBoundingClientRect().bottom);
      const placed = [];
      labels.forEach((label) => {
        const overlay = label.closest('.overlay');
        let offset = 0;
        for (let attempt = 0; attempt < 20; attempt += 1) {
          const rect = label.getBoundingClientRect();
          const collision = placed.find((placedRect) => overlaps(rect, placedRect));
          if (!collision) {
            placed.push(rect);
            return;
          }
          offset += Math.max(12, Math.ceil(rect.bottom - collision.top + 6));
          overlay.style.setProperty('--stack-offset', offset + 'px');
        }
        placed.push(label.getBoundingClientRect());
      });
    };
    const scheduleTextOverlayLayout = () => {
      requestAnimationFrame(() => requestAnimationFrame(arrangeTextOverlays));
      setTimeout(arrangeTextOverlays, 250);
    };
    const markerHtml = (marker) => {
      const accent = marker.accentColor || '#2f6f3e';
      const title = esc(marker.title);
      const arrow = esc(marker.arrow);
      const image = marker.imageUrl ? '<img src="' + esc(marker.imageUrl) + '" alt="">' : '';
      let inner = '';
      if (marker.kind === 'spotStop') {
        inner = '<div class="thumb-label">' + image + '<span>' + title + '</span></div><div class="dot"></div>';
      } else if (marker.kind === 'photo') {
        inner = '<div class="photo-box">' + image + '</div>';
      } else if (marker.kind === 'spot') {
        inner = '<div class="circle-photo">' + image + '</div>';
      } else if (marker.kind === 'mission') {
        inner = '<div class="mission">⚑ ' + title + '</div><div class="mission-tip"></div>';
      } else if (marker.kind === 'detailSpot') {
        inner = '<div class="spot-pointer"><span></span></div>';
      } else if (marker.kind === 'selectedLocation') {
        inner = '<div class="label nearest-label">' + title + '</div><div class="spot-pointer"><span></span></div>';
      } else if (marker.kind === 'currentLocation') {
        inner = '<div class="current-location"><span></span></div>';
      } else if (marker.kind === 'nearestStop' || marker.kind === 'boardingStop') {
        inner = '<div class="label nearest-label">' + title + '</div><div class="dot nearest-dot"></div>';
      } else {
        inner = '<div class="dot"></div>';
      }
      const tag = marker.id ? 'button' : 'div';
      const overlayClass = marker.kind === 'currentLocation'
        ? 'overlay current-location-overlay'
        : 'overlay';
      return '<' + tag + ' class="' + overlayClass + '" style="--accent:' + accent + '" onclick="sendTap(\\'' + esc(marker.id) + '\\')">' + inner + '</' + tag + '>';
    };
    kakao.maps.load(() => {
      const center = new kakao.maps.LatLng(data.center.lat, data.center.lng);
      const map = new kakao.maps.Map(document.getElementById('map'), {
        center,
        level: data.zoom
      });
      const sendCenter = () => {
        if (window.B4YMap) {
          const currentCenter = map.getCenter();
          window.B4YMap.postMessage(JSON.stringify({
            type: 'centerChanged',
            lat: currentCenter.getLat(),
            lng: currentCenter.getLng()
          }));
        }
      };
      if (!data.interactive) {
        map.setDraggable(false);
        map.setZoomable(false);
      }
      if (data.interactive) {
        kakao.maps.event.addListener(map, 'dragend', sendCenter);
        kakao.maps.event.addListener(map, 'zoom_changed', sendCenter);
      }
      data.polylines.forEach((line) => {
        new kakao.maps.Polyline({
          map,
          path: line.points.map((point) => new kakao.maps.LatLng(point.lat, point.lng)),
          strokeWeight: line.strokeWidth,
          strokeColor: line.color,
          strokeOpacity: 0.9,
          strokeStyle: 'solid'
        });
      });
      data.markers.forEach((marker) => {
        new kakao.maps.CustomOverlay({
          map,
          position: new kakao.maps.LatLng(marker.lat, marker.lng),
          content: markerHtml(marker),
          xAnchor: 0.5,
          yAnchor: marker.kind === 'currentLocation' ? 0.5 : 1
        });
      });
      scheduleTextOverlayLayout();
      kakao.maps.event.addListener(map, 'idle', scheduleTextOverlayLayout);
      document.querySelectorAll('#map .overlay img').forEach((image) => {
        image.addEventListener('load', scheduleTextOverlayLayout, { once: true });
      });
      if (data.fitToContent) {
        const fitMap = () => {
          map.relayout();
          const bounds = new kakao.maps.LatLngBounds();
          let hasPoint = false;
          const fitPoints = data.fitPoints.length > 0
            ? data.fitPoints
            : [
                ...data.polylines.flatMap((line) => line.points),
                ...data.markers.map((marker) => marker)
              ];
          fitPoints.forEach((point) => {
            bounds.extend(new kakao.maps.LatLng(point.lat, point.lng));
            hasPoint = true;
            if (data.fitCenter) {
              bounds.extend(new kakao.maps.LatLng(
                (2 * data.fitCenter.lat) - point.lat,
                (2 * data.fitCenter.lng) - point.lng
              ));
            }
          });
          if (hasPoint) {
            map.setBounds(bounds, 48, 56, 48, 56);
            if (map.getLevel() < data.zoom) {
              map.setLevel(data.zoom);
            }
            if (data.fitCenter) {
              map.setCenter(new kakao.maps.LatLng(
                data.fitCenter.lat,
                data.fitCenter.lng
              ));
            }
          }
        };
        requestAnimationFrame(fitMap);
        setTimeout(fitMap, 100);
      } else {
        const recenter = () => {
          map.relayout();
          map.setCenter(center);
        };
        requestAnimationFrame(recenter);
        setTimeout(recenter, 100);
      }
    });
  </script>
</body>
</html>
''';
  }
}

*/
}

String _cssHex(Color color) {
  final value = color.toARGB32();
  final rgb = value & 0x00ffffff;
  return '#${rgb.toRadixString(16).padLeft(6, '0')}';
}
