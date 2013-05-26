# Requires
extendr = require('extendr')
eachr = require('eachr')
{TaskGroup} = require('taskgroup')
typeChecker = require('typechecker')
safefs = require('safefs')
balUtil = require('bal-util')
pathUtil = require('path')
superAgent = require('superagent')

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
		timeout: 10*1000

	# Constructor
	constructor: (config) ->
		# Extend and dereference our configuration
		@config = extendr.extend({},@config,config)

		# Chain
		@

	# Read Feeds
	# feeds = {feedName:feedDetails}, feedDetails={url}
	# next(err,result)
	readFeeds: (feeds,next) ->
		# Prepare
		feedr = @
		{log,logError} = @config
		failures = 0
		isArray = typeChecker.isArray(feeds)
		result = if isArray then [] else {}

		# Tasks
		tasks = new TaskGroup().setConfig(concurrency:0).once 'complete', (err) ->
			log? (if failures then 'warn' else 'debug'), 'Feedr finished fetching', (if failures then "with #{failures} failures" else '')
			return next(err,result)

		# Feeds
		eachr feeds, (feedDetails,feedName) -> tasks.addTask (complete) ->
			# Prepare
			if typeChecker.isString(feedDetails)
				feedDetails = {url:feedDetails}
			feedDetails.name ?= feedName

			# Read
			feedr.readFeed feedDetails, (err,data) ->
				# Handle
				if err
					log? 'debug', "Feedr failed to fetch [#{feedDetails.url}] to [#{feedDetails.path}]"
					logError? err
					++failures
				else
					if isArray
						result.push(data)
					else
						result[feedName] = data

				# Complete
				return complete()

		# Fetch the tmp path we will be writing to
		if feedr.config.tmpPath
			tasks.run()
		else
			balUtil.getTmpPath (err,tmpPath) ->
				return next(err)  if err
				feedr.config.tmpPath = tmpPath
				tasks.run()

		# Chain
		@


	# Read Feed
	# feedDetails = {name,url} or url
	# next(err,data)
	readFeed: (feedDetails,next) ->
		# Prepare
		feedr = @
		# Fetch the tmp path we will be writing to
		unless feedr.config.tmpPath
			balUtil.getTmpPath (err,tmpPath) ->
				return next(err)  if err
				feedr.config.tmpPath = tmpPath
				feedr.readFeed(feedDetails,next)
			return @

		# Prepare
		{log,tmpPath,cacheTime,cache,xml2jsOptions} = @config
		feedDetails = {url:feedDetails,name:feedDetails}  if typeChecker.isString(feedDetails)
		feedDetails.hash ?= require('crypto').createHash('md5').update("feedr-"+JSON.stringify(feedDetails.url)).digest('hex');
		feedDetails.path ?= pathUtil.join(tmpPath, feedDetails.hash)
		feedDetails.name ?= feedDetails.hash

		# Cleanup some response data
		cleanData = (data) ->
			keys = []
			# Discover the keys inside data, and delve deeper
			for own key,value of data
				if typeChecker.isPlainObject(data)
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
			safefs.writeFile feedDetails.path, JSON.stringify(data), (err) ->
				# Check
				return next(err)  if err

				# Return the parsed data
				return next(null,data)

		# Get the file via reading the cached copy
		viaCache = ->
			# Log
			log? 'debug', "Feedr fetched [#{feedDetails.url}] from cache"

			# Check the the file exists
			safefs.exists feedDetails.path, (exists) ->
				# Check it exists
				return next()  unless exists

				# It does exist, so let's continue to read the cached fie
				safefs.readFile feedDetails.path, (err,dataBuffer) ->
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
			request = superAgent[feedDetails.method or 'get'](feedDetails.url).timeout(60*1000)
			request.set('user-agent': 'Wget/1.14 (linux-gnu)')
			request.set(feedDetails.headers)  if feedDetails.headers
			request.query(feedDetails.query)  if feedDetails.query
			request.send(feedDetails.body)    if feedDetails.body
			request.end (err,res) ->
				# If the request fails then we should revert to the cache
				handleError = (err) ->
					return viaCache()  if cache isnt false
					return next(err)
				return handleError(err)  if err

				# Trim the requested data
				body = (res.text or '').toString().trim()

				# Parse the requested data
				# xml
				if /^</.test(body)
					xml2js = require('xml2js')
					if typeChecker.isString(xml2jsOptions)
						xml2jsOptions = xml2js.defaults[xml2jsOptions]
					parser = new xml2js.Parser(xml2jsOptions)
					parser.on 'end', (data) ->
						# write
						writeFeed(data)
					try
						parser.parseString(body)
					catch err
						return handleError(err)  if err
				else
					# strip comments, whitespace, and semicolons from the start and finish
					# targets facebook graph api
					body = body.replace(/(^([\s\;]|\/\*\*\/)+|[\s\;]+$)/g,'')

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
							return handleError(err)  if err
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