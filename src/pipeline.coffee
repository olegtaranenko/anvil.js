# Uglify: JavaScript parser and compressor/beautifier toolkit -- 
# See https://github.com/mishoo/UglifyJS for more info
jsp = require( "uglify-js" ).parser
pro = require( "uglify-js" ).uglify

# A Node-compatible port of Douglas Crockford's JSLint -- 
jslint = require( "readyjslint" ).JSLINT

# Gzip for Node -- 
gzipper = require( "gzip" )

# CSS Minifier --
# See https://github.com/jbleuzen/node-cssmin
cssminifier = require( "cssmin" )

# ## StylePipeline ##
# The set of post-processes that happen to completed style outputs.
# These include minification, wrapping and
# finalization depending on the build configuration.
class StylePipeline

	constructor: ( @config, @fp, @minifier, @scheduler, @log ) ->
		_.bindAll( this )

	# ## process ##
	# Take the list of files and minify, wrap and finalize them
	# according to configuration. In the event that files are minified,
	# this function will create a seperate set of files to separate
	# processing between developer friendly and deployment friendly files.
	# _files {Array}_: the list of files to process
	# _onComplete {Array}_: the function to call with the list of files
	process: ( files, onComplete ) ->
		self = this
		forAll = @scheduler.parallel
		forAll files, @wrap, () ->
			minified = []
			if self.config.cssmin
				minified = _.map( files, ( x ) -> _.clone x )
			forAll files, self.finalize, () -> 
				forAll minified, self.minify, () -> 
					forAll minified, self.finalize, () -> 
						onComplete( files.concat minified )

	# ## minify ##
	# Uses the cssmin lib to minify the output styles
	# _file {String}_: the file to minify
	# _onComplete {Function}_: the function to call after minification has completed
	minify: ( file, onComplete ) ->
		if @config.cssmin
			self = this
			ext = file.ext()
			newFile = file.name.replace ext, ".min.css"
			self.fp.transform( 
				[ file.workingPath, file.name ],
				( content, onTransform ) ->
					onTransform( self.minifier.cssmin content )
				, [ file.workingPath, newFile ],
				( ) ->
					file.name = newFile
					onComplete()
			)
		else
			onComplete()

	# ## finalize ##
	# Finalize, for lack of a better term, puts header and footer content around the file's contents.
	# This step is different than wrapping because it happens AFTER minification and won't get
	# mangled as a result.
	# _file {String}_: the file to finalize
	# _onComplete {Function}_: the function to call after finalization has completed
	finalize: ( file, onComplete ) ->
		self = this
		if @config.finalize and @config.finalize.style
			header = @config.finalize.style.header
			footer = @config.finalize.style.footer
			@fp.transform( 
				[ file.workingPath, file.name ], 
				( content, onTransform ) ->
					if header
						content = header + content
					if footer
						content = content + footer
					onTransform content
				, [ file.workingPath, file.name ],
				onComplete
			)
		else
			onComplete()

	# ## finalize ##
	# Wraps the contents of the file with a prefix and suffix before minification occurs.
	# _file {String}_: the file to wrap
	# _onComplete {Function}_: the function to call after wrapping has completed
	wrap: ( file, onComplete ) ->
		self = this
		if @config.wrap and @config.wrap.style
			prefix = @config.wrap.style.prefix
			suffix = @config.wrap.style.suffix
			@fp.transform( 
				[ file.workingPath, file.name ], 
				( content, onTransform ) ->
					if prefix
						content = prefix + content
					if suffix
						content = content + suffix
					onTransform content
				, [ file.workingPath, file.name ],
				onComplete
			)
		else
			onComplete()

# ## StylePipeline ##
# The set of post-processes that happen to completed style outputs. 
# These include minification, wrapping and
# finalization depending on the build configuration.
class SourcePipeline

	constructor: ( @config, @fp, @minifier, @scheduler, @log ) ->
		_.bindAll( this )

	# ## process ##
	# Take the list of files and minify, wrap and finalize them
	# according to configuration. In the event that files are minified,
	# this function will create a seperate set of files to separate
	# processing between developer friendly and deployment friendly files.
	# _files {Array}_: the list of files to process
	# _onComplete {Array}_: the function to call with the list of files
	process: ( files, onComplete ) ->
		self = this
		forAll = @scheduler.parallel
		forAll files, @wrap, () ->
			minify = []
			if self.config.uglify
				minify = _.map( files, ( x ) -> _.clone x )
			forAll files, self.finalize, () -> 
				forAll minify, self.minify, () -> 
					forAll minify, self.finalize, () -> 
						onComplete( files.concat minify )

	# ## minify ##
	# Uses the uglify lib to minify the output source
	# _file {String}_: the file to minify
	# _onComplete {Function}_: the function to call after minification has completed
	minify: ( file, onComplete ) ->
		if @config.uglify
			self = this
			ext = file.ext()
			newFile = file.name.replace ext, ".min.js"
			@log.onStep "Uglifying #{ newFile }"
			@fp.transform( 
				[ file.workingPath, file.name ],
				( content, onTransform ) ->
					self.minifier content, ( err, result ) ->
						if err
							self.log.onError "Error minifying #{ file.name } : \r\n\t #{ err }"
							result = content
						onTransform( result )
				, [ file.workingPath, newFile ],
				() ->
					file.name = newFile
					onComplete()
			)
		else
			onComplete()

	# ## finalize ##
	# Finalize, for lack of a better term, puts header and footer content around the file's contents.
	# This step is different than wrapping because it happens AFTER minification and won't get
	# mangled as a result.
	# _file {String}_: the file to finalize
	# _onComplete {Function}_: the function to call after finalization has completed
	finalize: ( file, onComplete ) ->
		self = this
		if @config.finalize and @config.finalize.source
			@log.onStep "Finalizing #{ file.name }"
			header = @config.finalize.source.header
			footer = @config.finalize.source.footer
			@fp.transform( 
				[ file.workingPath, file.name ], 
				( content, onTransform ) ->
					if header
						content = header + content
					if footer
						content = content + footer
					onTransform content
				, [ file.workingPath, file.name ],
				() ->
					onComplete()
			)
		else
			onComplete()

	# ## finalize ##
	# Wraps the contents of the file with a prefix and suffix before minification occurs.
	# _file {String}_: the file to wrap
	# _onComplete {Function}_: the function to call after wrapping has completed
	wrap: ( file, onComplete ) ->
		self = this
		if @config.wrap and @config.wrap.source
			prefix = @config.wrap.source.prefix
			suffix = @config.wrap.source.suffix  
			@fp.transform( 
				[ file.workingPath, file.name ], 
				( content, onTransform ) ->
					if prefix
						content = prefix + content
					if suffix
						content = content + suffix
					onTransform content
				, [ file.workingPath, file.name ],
				onComplete
			)
		else
			onComplete()

# ## MarkupPipeline ##
# Provides is a placeholder as there are currently
# no post-process steps for markup.
class MarkupPipeline

	constructor: () ->

# ## PostProcessor ##
# A provider abstraction around post-process steps for each resource
# type that allows Anvil to have a 'branchless' pipeline for all 
# resource types
class PostProcessor

	constructor: ( @config, @fp, @scheduler, @log ) ->

		uglify = ( source, callback ) ->
			try
				ast = jsp.parse source
				ast = pro.ast_mangle ast
				ast = pro.ast_squeeze ast
				callback undefined, pro.gen_code ast
			catch err
				callback err, ""

		@style = new StylePipeline @config, @fp, cssminifier, @scheduler, @log
		@source = new SourcePipeline @config, @fp, uglify, @scheduler, @log
		@markup = {
			process: ( files, onComplete ) -> onComplete files
		}


exports.postProcessor = PostProcessor