console.log('[Hook] loaded');

/**
 * Graph post-processor hook
 * @param {graphlib.Graph} graph Identifiers graph
 * @param {String} root Root node (entry point)
 * @return {String[]} Additional modules to split (identifiers)
 */
module.exports = function(graph, root) {
    console.log('[Hook] called with', graph.nodes().length, 'nodes and "' + root + '" entry point');

    // you can define virtual nodes
    graph.setNode('fakeNode');
    // you can link/unlink nodes
    graph.setEdge(root, 'fakeNode');
    graph.setEdge('foo_Bar', 'fakeNode');

    // you can return additional modules to split
    // return ['Keeped'];
    return null;
}
