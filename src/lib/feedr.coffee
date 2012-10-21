# Requires
balUtil = require('bal-util')
request = require('request')
pathUtil = require('path')

# Define
class Feedr
	# Configuration
	config:
		log: null
		logError: null
		tmpPath: null
		cache: true
		cacheTime: 1000*60*5
		xmljsOptions: null


	# Constructor
	constructor: (config) ->
		# Extend and dereference our configuration
		@config = balUtil.extend({},@config,config)

		# Chain
		@


	# Read Feeds
	# next(err,result)
	readFeeds: (feeds,next) ->
		# Prepare
		feedr = @
		{log,logError} = @config
		result = {}
		failures = 0

		# Tasks
		tasks = new balUtil.Group (err) ->
			log? (if failures then 'warn' else 'debug'), 'Feedr finished fetching', (if failures then "with #{failures} failures" else '')
			return next(err,result)

		# Feeds
		balUtil.each feeds, (feedDetails,feedName) ->
			tasks.push (complete) ->
				feedr.readFeed feedName, feedDetails, (err,data) ->
					# Handle
					if err
						log? 'debug', "Feedr failed to fetch [#{feedDetails.url}] to [#{feedDetails.path}]"
						logError? err
						++failures
					else
						result[feedName] = data
					return complete()

		# Fetch the tmp path we will be writing to
		if feedr.config.tmpPath
			tasks.async()
		else
			balUtil.getTmpPath (err,tmpPath) ->
				return next(err)  if err
				feedr.config.tmpPath = tmpPath
				tasks.async()

		# Chain
		@


	# Read Feed
	# next(err,data)
	readFeed: (feedName,feedDetails,next) ->
		# Prepare
		{log,tmpPath,cacheTime,cache,xml2jsOptions} = @config
		feedHash = require('crypto').createHash('md5').update("feedr-"+JSON.stringify(feedDetails)).digest('hex');
		feedDetails.path = pathUtil.join(tmpPath, feedHash)

		# Cleanup some response data
		cleanData = (data) ->
			keys = []
			# Discover the keys inside data, and delve deeper
			for own key,value of data
				if balUtil.isPlainObject(data)
					data[key] = cleanData(value)
				keys.push(key)
			# Check if we are a simple rest object
			# If so, make it a simple value
			if keys.length is 1 and keys[0] is '_content'
				data = data._content
			# Return the result
			return data

		# Write the feed
		writeFeed = (data) ->
			# Store the parsed data in the cache somewhere
			balUtil.writeFile feedDetails.path, JSON.stringify(data), (err) ->
				# Check
				return next(err)  if err

				# Return the parsed data
				return next(null,data)

		# Get the file via reading the cached copy
		viaCache = ->
			# Log
			log? 'debug', "Feedr fetched [#{feedDetails.url}] from cache"

			# Check the the file exists
			balUtil.exists feedDetails.path, (exists) ->
				# Check it exists
				return next()  unless exists

				# It does exist, so let's continue to read the cached fie
				balUtil.readFile feedDetails.path, (err,dataBuffer) ->
					# Check
					return next(err)  if err

					# Parse the cached data
					data = JSON.parse(dataBuffer.toString())

					# Rreturn the parsed cached data
					return next(null,data)

		# Get the file via doing a new request
		viaRequest = ->
			# Log
			log? 'debug', "Feedr is fetching [#{feedDetails.url}] to [#{feedDetails.path}]"

			# Fetch and Save
			request feedDetails.url, (err,response,body) ->
				# If the request fails then we should revert to the cache
				return viaCache()  if err

				# Trim the requested data
				body = body.trim()

				# Parse the requested data
				# xml
				if /^</.test(body)
					xml2js = require('xml2js')
					if balUtil.isString(xml2jsOptions)
						xml2jsOptions = xml2js.defaults[xml2jsOptions]
					parser = new xml2js.Parser(xml2jsOptions)
					parser.on 'end', (data) ->
						# write
						writeFeed(data)
					parser.parseString(body)
				else
					# jsonp/json
					try
						# strip the jsonp callback if it exists, and try parse
						body = body.replace(/^[a-z0-9]+/gi,'').replace(/^\(|\)$/g,'')
						data = JSON.parse(body)
					catch err
						# strip some dodgy escaping and try parse
						try
							body = body.replace(/\\'/g,"'")
							data = JSON.parse(body)
						catch err
							return next(err)  if err
					finally
						# Clean the data if desired
						if feedDetails.clean
							log? 'debug', "Feedr is cleaning data from [#{feedDetails.url}]"
							data = cleanData(data)

						# Write
						writeFeed(data)

		# Check if we should get the data from the cache or do a new request
		if cache is false
			viaRequest()
		else
			balUtil.isPathOlderThan feedDetails.path, cacheTime, (err,older) ->
				# Check
				return next(err)  if err

				# The file doesn't exist, or exists and is old
				if older is null or older is true
					# Refresh
					return viaRequest()
				# The file exists and relatively new
				else
					# Get from cache
					return viaCache()

		# Chain
		@

# Export
module.exports = {Feedr}