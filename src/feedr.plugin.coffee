# Export Plugin
module.exports = (BasePlugin) ->
	# Requires
	balUtil = require('bal-util')
	request = require('request')
	osenv = require('osenv')
	pathUtil = require('path')

	# Define Plugin
	class FeedrPlugin extends BasePlugin
		# Plugin Name
		name: 'feedr'

		# Render Before
		# Read the feeds here
		renderBefore: ({templateData}, next) ->
			# Prepare
			feedr = @
			feedr.config.feeds or= {}
			templateData.feedr or= {}
			templateData.feedr.feeds or= {}

			# Tasks
			tasks = new balUtil.Group (err) ->
				return next(err)

			# Feeds
			balUtil.each feedr.config.feeds, (feedData,feedName) ->
				tasks.push (complete) ->
					feedr.readFeed feedName, feedData, (err,data) ->
						return complete(err)  if err
						templateData.feedr.feeds[feedName] = data
						return complete(err)

			# Fetch the tmp path we will be writing to
			if feedr.config.tmpPath
				tasks.async()
			else
				osenv.tmpdir (err,tmpPath) ->
					return next(err)  if err
					feedr.config.tmpPath = tmpPath
					tasks.async()

		# Read Feeds
		readFeed: (feedName,feedData,next) ->
			# Prepare
			feedData.path = pathUtil.join(@config.tmpPath, "docpad-feedr-#{feedName}")

			# Write the feed
			writeFeed = (data) ->
				# Store the parsed data in the cache somewhere
				balUtil.writeFile feedData.path, JSON.stringify(data), (err) ->
					# Check
					return next(err)  if err

					# Return the parsed data
					return next(null,data)

			# Get the file via reading the cached copy
			viaCache = ->
				# Check the the file exists
				balUtil.exists feedData.path, (exists) ->
					# Check it exists
					return next()  unless exists

					# It does exist, so let's continue to read the cached fie
					balUtil.readFile feedData.path, (err,dataBuffer) ->
						# Check
						return next(err)  if err

						# Parse the cached data
						data = JSON.parse(dataBuffer.toString())

						# Rreturn the parsed cached data
						return next(null,data)

			# Get the file via doing a new request
			viaRequest = ->
				request feedData.url, (err,response,body) ->
					# If the request fails then we should revert to the cache
					return viaCache()  if err

					# Trim the requested data
					body = body.trim()

					# Parse the requested data
					if /^[\[\{]/.test(body)
						# json
						data = JSON.parse(body)
						writeFeed(data)
					else if /^</.test(body)
						# xml
						xml2js = require("xml2js")
						parser = new xml2js.Parser()
						parser.on 'end', (data) ->
							writeFeed(data)
						parser.parseString(body)
					else
						# jsonp
						body = body.replace(/^[a-z0-9]+/gi, '')
						data = JSON.parse(body)
						writeFeed(data)

			# Check if we should get the data from the cache or do a new request
			balUtil.isPathOlderThan feedData.path, 1000*60*5, (err,older) ->
				# Check
				return next(err)  if err

				# The file doesn't exist, or exists and is old
				if older is null or older is true
					# Refresh
					viaRequest()
				# The file exists and relatively new
				else
					# Get from cache
					viaCache()

			# Chain
			@