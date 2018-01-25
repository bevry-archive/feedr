# History

## v3.0.0 2018 January 25
- Minimum node version is now version 4 due to the nested dependencies [hoek](https://www.npmjs.com/package/hoek) and [hawk](https://www.npmjs.com/package/hawk) publishing code that does not work with earlier node verisons - if only they used [editions](https://github.com/bevry/editions)
- Updated base files
- Updated dependencies

## v2.13.5 2017 February 28
- Internal: swapped a `forof` loop for `forin` loop, for better compat with old environments
- Added error for `checkResponse` instead of `check`

## v2.13.4 2017 February 28
- Fixed checks never firing (regression since v2.10.0)
- Updated dependencies
- Updated base files

## v2.13.3 2016 June 18
- Fixed legacy API `require('feedr').Feedr` not existing (regression since v2.13.0)

## v2.13.2 2016 June 13
- Fixed unknown clear method error (regression since v2.13.0)
- By default, use all plugins, like v2.12.0 and earlier (regression since v2.13.0)
	- Thanks to [Chris Krycho](https://github.com/chriskrycho) for #6](https://github.com/bevry/feedr/issues/6)

## v2.13.1 2016 June 8
- Meta change, correct syntaxes that are used in editions

## v2.13.0 2016 June 8
- Converted from CoffeeScript to JavaScript
- Updated dependencies

## v2.12.0 2015 March 17
- Better YAML parser

## v2.11.1 2015 March 16
- Updated dependencies

## v2.11.0 2015 February 7
- Updated dependencies

## v2.10.4 2014 December 12
- Certain failures will now emit warning messages
- Updated dependencies

## v2.10.3 2014 August 8
- Fixed with better tests

## v2.10.2 2014 August 8
- Fixed specific parsing

## v2.10.1 2014 August 8
- Fixed xml parsing

## v2.10.0 2014 August 8
- Large internal refactor
- `checkResponse` is now renamed to `check`, b/c enabled
- If a feed fails, the `err` argument will indicate this instead of merely outputting the error
- Feed details are now updated on the inputted feed details object, instead of a clone
- Now supports `raw`/`false` parse option

## v2.9.1 2014 August 3
- Updated dependencies

## v2.9.0 2014 May 21
- `cache` option now defaults to one day `1000*60*60*24` to avoid superflous requests, refer to the updated readme for what the new values mean
- `parse` option is now only a boolean
- parsing auto-detection now checks content-types as well as the previous extension check
- Updated dependencies

## v2.8.0 2014 May 3
- Added support for `"preferred"` and millisecond values for `cache` configuration option
- Updated dependencies

## v2.7.7 2014 January 10
- Updated dependencies

## v2.7.6 2014 January 2
- Updated dependencies
- More debug log messages

## v2.7.5 2013 November 27
- Use the `Wget/1.14 (linux-gnu)` User-Agent by default
- Updated dependencies

## v2.7.4 2013 November 13
- `readFeeds` can now accept default options to apply to each feed that will be ready

## v2.7.3 2013 October 31
- Can now parse CSON files

## v2.7.2 2013 October 4
- Fixed `checkResponse` option
- Better catching of errors with invalid JSON

## v2.7.1 2013 October 3
- Fixed `TypeError: Cannot call method 'toString' of null` (regression since v2.7.0)

## v2.7.0 2013 October 3
- Can now parse yaml files
- Can now customise parsing via `parse` feed option
- Parsing is now determined by extensions instead of file formats (b/c break)
	- If your url does not have an extension you must eplicitly set the `parse` feed option

## v2.6.0 2013 October 2
- Some options have changed (b/c break)
- Much more intelligent cache handling
	- We now use the expires and etag headers for caching
- Added the ability to customise the request options
- Dependency upgrades

## v2.5.1 2013 June 29
- Dependency upgrades

## v2.5.0 2013 May 27
- `cache`, `cacheTime`, `timeout`, `checkResult(data)` can now be specified on the feed details
- `checkResult(data)` should return an Error instance if it finds a problem with the fetched data
- `cacheTime` and `checkResult` have default implementations for github

## v2.4.4 2013 April 22
- Dependency upgrades

## v2.4.3 2013 March 20
- Added support for facebook graph api

## v2.4.2 2013 February 12
- Added support for gzip

## v2.4.1 2013 February 1
- Added timeout support
- If `cache: false` then we should never revert to cache (even if request fails)

## v2.4.0 2012 December 2
- Dropped the request dependency

## v2.3.0 2012 November 2
- Changed the signature of `readFeed` from `feedName, feedDetails, next` to `feedDetails, next` where `feedDetails = {name,url} or url`
- `readFeeds` can now accept an array
- Fixed caching when calling `readFeed` instead of `readFeeds`

## v2.2.0 2012 October 22
- Abstracted out from the [feedr docpad plugin](http://docpad.org/plugin/feedr)

## v2.1.0 2012 August 19
- Better handling of jsonp responses
- Better handling of bad json responses
- `"key": {"_content": "the actual value"}` inside responses will be converted to `"key": 'the actual value"` if `clean` is set to `true` inside the feed configuration

## v2.0.2 2012 August 10
- Re-added markdown files to npm distribution as they are required for the npm website
- Fixed a caching conflict issue when two feeds have the same name across different projects
- Added the configuration options `refreshCache` and `cacheTime`

## v2.0.1 2012 July 8
- Removed underscore dependency
- Fixed path exists warning
- Will now store cached files inside the operating systems actual tmp path, instead of always assuming it is `/tmp`
	- Customisable by the `tmpPath` configuration option

## v1.0.0 2012 April 14
- Updated for DocPad v5.0

## v0.2.0 2012 April 6
- Now exposes `@feedr.feeds` to the `templateData` instead of `@feeds`

## v0.1.0 2012 March 23
- Initial working version for [Benjamin Lupton's Website](https://github.com/balupton/balupton.docpad)
