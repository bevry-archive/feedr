## History

- v2.7.3 October 31, 2013
	- Can now parse CSON files

- v2.7.2 October 4, 2013
	- Fixed `checkResponse` option
	- Better catching of errors with invalid JSON

- v2.7.1 October 3, 2013
	- Fixed `TypeError: Cannot call method 'toString' of null` (regression since v2.7.0)

- v2.7.0 October 3, 2013
	- Can now parse yaml files
	- Can now customise parsing via `parse` feed optio
	- Parsing is now determined by extensions instead of file formats (b/c break)
		- If your url does not have an extension you must eplicitly set the `parse` feed optionn

- v2.6.0 October 2, 2013
	- Some options have changed (b/c break)
	- Much more intelligent cache handling
		- We now use the expires and etag headers for caching
	- Added the ability to customise the request options
	- Dependency upgrades

- v2.5.1 June 29, 2013
	- Dependency upgrades

- v2.5.0 May 27, 2013
	- `cache`, `cacheTime`, `timeout`, `checkResult(data)` can now be specified on the feed details
	- `checkResult(data)` should return an Error instance if it finds a problem with the fetched data
	- `cacheTime` and `checkResult` have default implementations for github

- v2.4.4 April 22, 2013
	- Dependency upgrades

- v2.4.3 March 20, 2013
	- Added support for facebook graph api

- v2.4.2 February 12, 2013
	- Added support for gzip

- v2.4.1 February 1, 2013
	- Added timeout support
	- If `cache: false` then we should never revert to cache (even if request fails)

- v2.4.0 December 2, 2012
	- Dropped the request dependency

- v2.3.0 November 2, 2012
	- Changed the signature of `readFeed` from `feedName, feedDetails, next` to `feedDetails, next` where `feedDetails = {name,url} or url`
	- `readFeeds` can now accept an array
	- Fixed caching when calling `readFeed` instead of `readFeeds`

- v2.2.0 October 22, 2012
	- Abstracted out from the [feedr docpad plugin](http://docpad.org/plugin/feedr)

- v2.1.0 August 19, 2012
	- Better handling of jsonp responses
	- Better handling of bad json responses
	- `"key": {"_content": "the actual value"}` inside responses will be converted to `"key": 'the actual value"` if `clean` is set to `true` inside the feed configuration

- v2.0.2 August 10, 2012
	- Re-added markdown files to npm distribution as they are required for the npm website
	- Fixed a caching conflict issue when two feeds have the same name across different projects
	- Added the configuration options `refreshCache` and `cacheTime`

- v2.0.1 July 8, 2012
	- Removed underscore dependency
	- Fixed path exists warning
	- Will now store cached files inside the operating systems actual tmp path, instead of always assuming it is `/tmp`
		- Customisable by the `tmpPath` configuration option

- v1.0.0 April 14, 2012
	- Updated for DocPad v5.0

- v0.2.0 April 6, 2012
	- Now exposes `@feedr.feeds` to the `templateData` instead of `@feeds`

- v0.1.0 March 23, 2012
	- Initial working version for [Benjamin Lupton's Website](https://github.com/balupton/balupton.docpad)