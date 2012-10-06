var _ = require( "underscore" );
var path = require( "path" );
var realFs = require( "fs" );
var commander = require( "commander" );
var machina = require( "machina" );
var postal = require( "postal" );
var fs = require( "./fs.mock.js" )( _, path );
var scheduler = require( "./scheduler.js" )( _ );
var events = require( "./eventAggregator.js" )( _ );
var bus = require( "./bus.js")( _, postal );
var anvil = require( "./anvil.js" )( _, scheduler, fs, events, bus );
var log = require( "./log.js" )( anvil );
require( "./consoleLogger" )( _, anvil );
require( "./utility.js")( _, anvil );
var plugin = require( "./plugin.js" )( _, anvil );
var manager = require( "./pluginManager.js" )( _, anvil );
var locator = require( "./pluginLocator.js" )( _, manager, anvil );
var config = require( "./config.js" )( _, commander, path, anvil );
var activityManager = require( "./activityManager.js" )( _, machina, anvil );
anvil.project.root = path.resolve( "./" );

var factory = function() {
	
	var harnessFactory = function( plugin, pluginPath ) {

		var preLoaded = [],
			instance = manager.loadPlugin( plugin, pluginPath, preLoaded );
		locator.preLoaded = preLoaded;
		locator.initPlugin( instance );

		var Harness = function() {
			_.bindAll( this );
			this.command = [ "node", "anvil.js" ];
			this.expected = [];
			this.files = [];
			this.fileSystem = fs;
			this.logs = {
				debug: [],
				"event": [],
				step: [],
				complete: [],
				warning: [],
				error: []
			};
			this.plugin = instance;
		};

		Harness.prototype.addFile = function( pathSpec, content ) {
			pathSpec = path.resolve( anvil.fs.buildPath( pathSpec ) );
			this.files.push( { path: pathSpec, content: content } );
		};

		Harness.prototype.generateAssertions = function( assert ) {
			return _.map( this.expected, function( file ) {
				return {
					description: "should create " + file.path,
					call: function( done ) {
						assert( anvil.fs.pathExists( file.path ), true );
						anvil.fs.read( file.path, function( actual ) {
							assert( file.content, actual );
							if( done ) {
								done();
							}
						} );
					}
				};
			} );
		};

		Harness.prototype.addCommandArgs = function( line ) {
			this.command = this.command.concat( line.split( " " ) );
		};

		Harness.prototype.expectFile = function( pathSpec, content ) {
			pathSpec = anvil.fs.buildPath( pathSpec );
			this.expected.push( { path: pathSpec, content: content } );
		};

		Harness.prototype.build = function( assert, done ) {
			var self = this;
			this.buildOnly( function() {
				done( self.generateAssertions( assert ) );
			} );
		};

		Harness.prototype.buildOnly = function( done ) {
			var self = this,
				handles = this.subscribe();
			anvil.on( "build.done", function() {
				_.each( handles, function( handle ) { handle.cancel(); } );
				done();
			} );
			anvil.scheduler.parallel(
				this.files,
				function( file, done ) {
					anvil.fs.write( file.path, file.content, function() { done(); } );
				},
				function() {
					config.initialize( self.command );
				} );
		};

		Harness.prototype.subscribe = function() {
			var self = this,
				handles = [];
			_.each( [ "debug", "event", "step", "complete", "warning", "error" ],
				function( type ) {
					handles.push( anvil.on( "log." + type, function( x ) {
						self.logs[ type ].push( x );
					} ) );
				}
			);
			return handles;
		};

		return new Harness();
	};

	var dataPath = fs.buildPath( [ "~/.anvilplugins", "plugins.json" ] ),
		packagePath = "./package.json";
	
	scheduler.parallel( [ dataPath, packagePath ], function( filePath, done ) {
		realFs.readFile( filePath, "utf8", function( error, content ) {
			if( !error ) {
				fs.write( filePath, content, function() {
					done();
				} );
			} else {
				done();
			}
		} );
	}, function() {} );

	return harnessFactory;
};

module.exports = factory;