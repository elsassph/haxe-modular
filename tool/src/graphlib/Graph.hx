package graphlib;

@:jsRequire('graphlib', 'Graph')
extern class Graph
{
	public function new(?options:GraphOptions);
	public function isDirected():Bool;
	public function isMultigraph():Bool;
	public function isCompound():Bool;
	public function setDefaultNodeLabel(value:String):Void;
	public function setDefaultEdgeLabel(value:String):Void;

	public function setGraph(label:String):Void;
	public function graph():String;

	public function setNode(v:String, ?label:String):Void;
	public function node(v:String):String;
	public function removeNode(v:String):Void;
	public function nodes():Array<String>;
	public function nodeCount():Int;
	/** Returns those nodes in the graph that have no in-edges. */
	public function sources():Array<String>;
	/** Returns those nodes in the graph that have no out-edges. */
	public function sinks():Array<String>;
	/** 
	 * Return all nodes that are predecessors of the specified node or undefined if 
	 * node v is not in the graph. 
	 */
	public function predecessors(v:String):Array<String>;
	/**
	 * Return all nodes that are successors of the specified node or undefined if 
	 * node v is not in the graph.
	 */
	public function successors(v:String):Array<String>;
	/**
	 * Return all nodes that are predecessors or successors of the specified node 
	 * or undefined if node v is not in the graph.
	 */
	public function neighbors(v:String):Array<String>;
	
	public function setEdge(v:String, w:String, ?label:String):Void;
	public function hasEdge(v:String, w:String, ?label:String):Bool;
	public function edge(v:String, w:String, ?label:String):String;
	public function removeEdge(v:String, w:String, ?label:String):String;
	public function edges():Array<String>;
	public function edgeCount():Int;
	/**
	 * Return all edges that point to the node v. Optionally filters those edges down 
	 * to just those coming from node u.
	 */
	public function inEdges(v:String, ?u:String):Array<String>;
	/**
	 * Return all edges that are pointed at by node v. Optionally filters those edges 
	 * down to just those point to w.
	 */
	public function outEdges(v:String, ?w:String):Array<String>;
	/**
	 * Returns all edges to or from node v regardless of direction. Optionally filters 
	 * those edges down to just those between nodes v and w regardless of direction.
	 */
	public function nodeEdges(v:String, ?w:String):Array<String>;
	
	/**
	 * Returns the node that is a parent of node v or undefined if node v does not have 
	 * a parent or is not a member of the graph. Always returns undefined for graphs 
	 * that are not compound.
	 */
	public function parent(v:String):String;
	/**
	 * Returns all nodes that are children of node v or undefined if node v is not in 
	 * the graph. Always returns [] for graphs that are not compound.
	 */
	public function children(v:String):String;
	/**
	 * Sets the parent for v to parent if it is defined or removes the parent for v 
	 * if parent is undefined. Throws an error if the graph is not compound.
	 */
	public function setParent(id:String, parentId:String):Graph;
}

typedef GraphOptions = {
	/**
	 * set to true to get a directed graph and false to get an undirected graph. 
	 * Default: true
	 */
	@:optional var directed:Bool;
	/**
	 * set to true to allow a graph to have multiple edges between the same pair of 
	 * nodes. Default: false.
	 */
	@:optional var multigraph:Bool;
	/**
	 * set to true to allow a graph to have compound nodes - nodes which can be the 
	 * parent of other nodes. Default: false.
	 */
	@:optional var compound:Bool;
}

@:jsRequire('graphlib/lib/alg')
extern class Alg 
{
	/**
	 * Finds all connected components in a graph and returns an array of these 
	 * components. Each component is itself an array that contains the ids of nodes 
	 * in the component.
	 */
	static public function components(g:Graph):Array<String>;
	/**
	 * This function performs a postorder traversal of the graph g starting at the 
	 * nodes vs. For each node visited, v, the function callback(v) is called.
	 */
	static public function postorder(g:Graph, v:String):Array<String>;
	/**
	 * This function performs a preorder traversal of the graph g starting at the 
	 * nodes vs. For each node visited, v, the function callback(v) is called.
	 */
	static public function preorder(g:Graph, vs:String):Array<String>;
}