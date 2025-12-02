import '../types/geo.dart';

class GraphNode {
  final String id;
  final LatLng coord;
  final Map<String, dynamic> attrs;
  const GraphNode({
    required this.id,
    required this.coord,
    this.attrs = const {},
  });
}

class GraphEdge {
  final String from;
  final String to;
  final double weightMeters;
  final Map<String, dynamic> attrs;
  const GraphEdge({
    required this.from,
    required this.to,
    required this.weightMeters,
    this.attrs = const {},
  });
}

class CampusGraph {
  final Map<String, GraphNode> nodes;
  final List<GraphEdge> edges;

  const CampusGraph({required this.nodes, required this.edges});

  Iterable<GraphEdge> neighbors(String nodeId) sync* {
    for (final e in edges) {
      if (e.from == nodeId) yield e;
    }
  }
}
