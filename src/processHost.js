var monitor = require( "forever-monitor" );

module.exports = function( _, anvil ) {

	var Process = function( id ) {
		this.id = id;
		this.goPostal( id );
	};

	Process.prototype.start = function() {

	};

	Process.prototype.stop = function() {

	};

	Process.prototype.start = function() {

	};

	anvil.addEvents( Process );


	var ProcessHost = function() {

		

	};

	anvil.addEvents( ProcessHost );

	return new ProcessHost();
};