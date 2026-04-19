extends RefCounted
class_name RelationshipNetwork

const RelationshipEdge = preload("res://scripts/data/relationship_edge.gd")

const RELATION_TYPES: Array[StringName] = [
	&"family",
	&"friend",
	&"rival",
	&"mentor",
	&"disciple",
	&"ally",
	&"enemy",
]

var _edges: Dictionary = {}
var _index_by_source: Dictionary = {}
var _index_by_target: Dictionary = {}


func add_edge(edge: RelationshipEdge) -> void:
	if edge == null:
		return
	var key := _edge_key(edge.source_id, edge.target_id)
	_edges[key] = edge
	_add_key_to_index(_index_by_source, edge.source_id, key)
	_add_key_to_index(_index_by_target, edge.target_id, key)


func remove_edge(source_id: StringName, target_id: StringName) -> void:
	var key := _edge_key(source_id, target_id)
	if not _edges.has(key):
		return
	var edge: RelationshipEdge = _edges[key]
	_edges.erase(key)
	_remove_key_from_index(_index_by_source, edge.source_id, key)
	_remove_key_from_index(_index_by_target, edge.target_id, key)


func get_edge(source_id: StringName, target_id: StringName) -> RelationshipEdge:
	var key := _edge_key(source_id, target_id)
	if _edges.has(key):
		return _edges[key]
	return RelationshipEdge.new()


func get_edges_for(source_id: StringName) -> Array[RelationshipEdge]:
	var result: Array[RelationshipEdge] = []
	var edge_keys: Array = _index_by_source.get(source_id, [])
	for edge_key_variant in edge_keys:
		var edge_key := str(edge_key_variant)
		if _edges.has(edge_key):
			result.append(_edges[edge_key])
	return result


func get_edges_involving(character_id: StringName) -> Array[RelationshipEdge]:
	var result: Array[RelationshipEdge] = []
	var visited: Dictionary = {}
	var source_keys: Array = _index_by_source.get(character_id, [])
	for edge_key_variant in source_keys:
		var edge_key := str(edge_key_variant)
		if _edges.has(edge_key) and not visited.has(edge_key):
			visited[edge_key] = true
			result.append(_edges[edge_key])
	var target_keys: Array = _index_by_target.get(character_id, [])
	for edge_key_variant in target_keys:
		var edge_key := str(edge_key_variant)
		if _edges.has(edge_key) and not visited.has(edge_key):
			visited[edge_key] = true
			result.append(_edges[edge_key])
	return result


func get_favor(source_id: StringName, target_id: StringName) -> int:
	var key := _edge_key(source_id, target_id)
	if not _edges.has(key):
		return 0
	var edge: RelationshipEdge = _edges[key]
	return edge.favor


func modify_favor(source_id: StringName, target_id: StringName, delta: int) -> void:
	var key := _edge_key(source_id, target_id)
	if not _edges.has(key):
		return
	var edge: RelationshipEdge = _edges[key]
	edge.favor = clampi(edge.favor + delta, -300, 300)


func get_relations_of_type(relation_type: StringName) -> Array[RelationshipEdge]:
	var result: Array[RelationshipEdge] = []
	for edge_variant in _edges.values():
		var edge: RelationshipEdge = edge_variant
		if edge.relation_type == relation_type:
			result.append(edge)
	return result


func get_allies(character_id: StringName, threshold: int = 50) -> Array[StringName]:
	var result: Array[StringName] = []
	for edge in get_edges_for(character_id):
		if edge.favor >= threshold:
			result.append(edge.target_id)
	return result


func get_enemies(character_id: StringName, threshold: int = -50) -> Array[StringName]:
	var result: Array[StringName] = []
	for edge in get_edges_for(character_id):
		if edge.favor <= threshold:
			result.append(edge.target_id)
	return result


func get_all_edges() -> Array[RelationshipEdge]:
	var result: Array[RelationshipEdge] = []
	for edge_variant in _edges.values():
		var edge: RelationshipEdge = edge_variant
		result.append(edge)
	return result


func edge_count() -> int:
	return _edges.size()


func to_dict() -> Dictionary:
	var edges_data: Array[Dictionary] = []
	for edge_variant in _edges.values():
		var edge: RelationshipEdge = edge_variant
		edges_data.append(edge.to_dict())
	return {"edges": edges_data}


static func from_dict(data: Dictionary) -> RelationshipNetwork:
	var network := RelationshipNetwork.new()
	var edges_data: Array = data.get("edges", [])
	for edge_data in edges_data:
		if edge_data is Dictionary:
			var edge: RelationshipEdge = RelationshipEdge.from_dict(edge_data)
			network.add_edge(edge)
	return network


func _edge_key(source_id: StringName, target_id: StringName) -> String:
	return "%s|%s" % [String(source_id), String(target_id)]


func _add_key_to_index(index: Dictionary, character_id: StringName, edge_key: String) -> void:
	if not index.has(character_id):
		index[character_id] = []
	var keys: Array = index[character_id]
	if not keys.has(edge_key):
		keys.append(edge_key)


func _remove_key_from_index(index: Dictionary, character_id: StringName, edge_key: String) -> void:
	if not index.has(character_id):
		return
	var keys: Array = index[character_id]
	keys.erase(edge_key)
	if keys.is_empty():
		index.erase(character_id)
