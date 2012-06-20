var path = require("path");
var fs = require("fs");
// load the plugins list from either the installed anvil instance OR
// assume this is active development and use a local path
var dataPath = path.join(path.dirname(fs.realpathSync(__filename, "./")), "../plugins.json");
var dataExists = path.existsSync( dataPath );
var plugins = dataExists ? require( dataPath ) : require( "./spec/plugin.json" );
var installPath = path.join(path.dirname(fs.realpathSync(__filename, "./")), "../plugins/");
var installPathExists = path.existsSync( installPath );
installPath = installPathExists ? installPath : "./spec/plugins/";

var pluginManagerFactory = function() {

	var PluginManager = function() {
		this.installPath = installPath;
	};

	PluginManager.prototype.getPlugins = function() {
		return plugins.list;
	};

	PluginManager.prototype.addPlugin = function( plugin, onComplete ) {
		if( ! _.any( plugins.list, function( x ) { return x == plugin; } ) ) {
			plugins.list.push( plugin );
			var json = JSON.stringify( plugins );
			fs.writeFile( dataPath, json, function( err ) {
				onComplete( err );
			} );
		} else {
			onComplete();
		}
	};

	PluginManager.prototype.removePlugin = function( plugin, onComplete ) {
		if( _.any( plugins.list, function( x ) { return x == plugin; } ) ) {
			plugins.list = _.filter( plugins.list, function( x ) { return x != plugin; } );
			var json = JSON.stringify( plugins );
			fs.writeFile( dataPath, json, function( err ) {
				onComplete( err );
			} );
		} else {
			onComplete();
		}
	};

	return new PluginManager();
};

module.exports = pluginManagerFactory;