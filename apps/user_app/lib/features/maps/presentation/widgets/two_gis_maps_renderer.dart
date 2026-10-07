import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/geo_point.dart';
import 'map_renderer.dart';

/// Real 2GIS rendering, via the MapGL JS API inside a WebView — the 2GIS
/// native Flutter SDK needs per-platform native setup, the JS API only needs
/// a key. Only ever constructed once `TWOGIS_API_KEY` is configured and the
/// platform can host a WebView (see `mapRendererProvider`), so CI/test runs
/// never touch it.
class TwoGisMapsRenderer implements MapRenderer {
  final String apiKey;

  const TwoGisMapsRenderer(this.apiKey);

  @override
  Widget build(BuildContext context, {required GeoPoint target, required String targetLabel}) {
    return _TwoGisMapView(
      html: buildTwoGisMapHtml(apiKey: apiKey, target: target, targetLabel: targetLabel),
    );
  }
}

/// JSON is a valid JS literal, but `</script>` inside a string would still
/// end the script tag early — hence the `<` escape.
String _jsLiteral(Object? value) => jsonEncode(value).replaceAll('<', r'<');

/// The page the WebView loads. Public for tests: it is plain string building
/// and the part that has to escape the provider's name safely.
String buildTwoGisMapHtml({
  required String apiKey,
  required GeoPoint target,
  required String targetLabel,
}) {
  final coordinates = _jsLiteral([target.longitude, target.latitude]); // 2GIS is [lon, lat]
  return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>html, body, #map { margin: 0; padding: 0; width: 100%; height: 100%; }</style>
<script src="https://mapgl.2gis.com/api/js/v1"></script>
</head>
<body>
<div id="map"></div>
<script>
  const map = new mapgl.Map('map', { center: $coordinates, zoom: 15, key: ${_jsLiteral(apiKey)} });
  new mapgl.Marker(map, { coordinates: $coordinates, label: { text: ${_jsLiteral(targetLabel)} } });
</script>
</body>
</html>
''';
}

class _TwoGisMapView extends StatefulWidget {
  final String html;

  const _TwoGisMapView({required this.html});

  @override
  State<_TwoGisMapView> createState() => _TwoGisMapViewState();
}

class _TwoGisMapViewState extends State<_TwoGisMapView> {
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..loadHtmlString(widget.html, baseUrl: 'https://mapgl.2gis.com');

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
