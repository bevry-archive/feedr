<!-- TITLE/ -->

# Feedr

<!-- /TITLE -->


<!-- BADGES/ -->

[![Build Status](https://img.shields.io/travis/bevry/feedr/master.svg)](http://travis-ci.org/bevry/feedr "Check this project's build status on TravisCI")
[![NPM version](https://img.shields.io/npm/v/feedr.svg)](https://npmjs.org/package/feedr "View this project on NPM")
[![NPM downloads](https://img.shields.io/npm/dm/feedr.svg)](https://npmjs.org/package/feedr "View this project on NPM")
[![Dependency Status](https://img.shields.io/david/bevry/feedr.svg)](https://david-dm.org/bevry/feedr)
[![Dev Dependency Status](https://img.shields.io/david/dev/bevry/feedr.svg)](https://david-dm.org/bevry/feedr#info=devDependencies)<br/>
[![Gratipay donate button](https://img.shields.io/gratipay/bevry.svg)](https://www.gratipay.com/bevry/ "Donate weekly to this project using Gratipay")
[![Flattr donate button](https://img.shields.io/badge/flattr-donate-yellow.svg)](http://flattr.com/thing/344188/balupton-on-Flattr "Donate monthly to this project using Flattr")
[![PayPayl donate button](https://img.shields.io/badge/paypal-donate-yellow.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=QB8GQPZAH84N6 "Donate once-off to this project using Paypal")
[![BitCoin donate button](https://img.shields.io/badge/bitcoin-donate-yellow.svg)](https://coinbase.com/checkouts/9ef59f5479eec1d97d63382c9ebcb93a "Donate once-off to this project using BitCoin")
[![Wishlist browse button](https://img.shields.io/badge/wishlist-donate-yellow.svg)](http://amzn.com/w/2F8TXKSNAFG4V "Buy an item on our wishlist for us")

<!-- /BADGES -->


<!-- DESCRIPTION/ -->

Use feedr to fetch the data from a remote url, respect its caching, and parse its data. Despite its name, it's not just for feed data but also for all data that you can feed into it (including binary data).

<!-- /DESCRIPTION -->


<!-- INSTALL/ -->

## Install

### [NPM](http://npmjs.org/)
- Use: `require('feedr')`
- Install: `npm install --save feedr`

<!-- /INSTALL -->


## Usage

``` javascript
// Prepare
var Feedr, feedr, feeds

// Create a new feedr instance
feedr = require('feedr').create({/* optional configuration */})

// Prepare our feeds that we want read
feeds = {
	github: "https://github.com/bevry/feedr/commits/master.atom",
	gittip: "https://www.gittip.com/balupton/public.json"
}

// Read a single feed
feedr.readFeed(feeds.github, {/* optional configuration */}, function(err, data, headers){
	console.log(err, data, headers)
})

// Read all the feeds together
feedr.readFeeds(feeds, {/* optional configuration */}, function(err, result){
	console.log(err, result.github, result.twitter)
})
```


## Configuration

Feed configuration defaults / global configuration properties are:

- `log` defaults to `null`, log function to use
- `tmpPath` defaults to system tmp path, the tempory path to cache our feedr results to
- `cache` defaults to one day `1000*60*60*24`, available values:
	- `Number` prefers to use the cache when it is within the range of the number in milliseconds
	- `true` prefers to use the cache when the response headers indicate that the cache is still valid
	- `"preferred"` will always use the cache if the cache exists
	- `false` will never use the cache
- `xml2jsOptions` defaults to `null`, the options to send to [xml2js](https://github.com/Leonidas-from-XIV/node-xml2js)
- `requestOptions` defaults to `null`, the options to send to [request](https://github.com/mikeal/request)

Feed configuration properties are:

- `url` required, the url to fetch
- `hash` defaults to hash of the url, the hashed url for caching
- `name` defaults to hash, the name of the feed for use in debugging
- `path` defaults to tmp feed path, the path to save the file to
- `parse` defaults to `true`, whether or not we should attempt to parse the response data, supported values are `xml`, `json`, `cson`, `yaml`, `string`, `raw`/`false`. If `true` will try all the available parsers. Can also be a function with the signature `({response, data, feed, feedr}, next(err, data))`
- `check` defaults to `true`, whether or not we should check the response data for custom error messages. Can also be a function with the signature `({response, data, feed, feedr}, next(err))`
- `xml2jsOptions` defaults to global value, the options to send to [xml2js](https://github.com/Leonidas-from-XIV/node-xml2js)
- `requestOptions` defaults to global value, the options to send to [request](https://github.com/mikeal/request)


<!-- HISTORY/ -->

## History
[Discover the change history by heading on over to the `HISTORY.md` file.](https://github.com/bevry/feedr/blob/master/HISTORY.md#files)

<!-- /HISTORY -->


<!-- CONTRIBUTE/ -->

## Contribute

[Discover how you can contribute by heading on over to the `CONTRIBUTING.md` file.](https://github.com/bevry/feedr/blob/master/CONTRIBUTING.md#files)

<!-- /CONTRIBUTE -->


<!-- BACKERS/ -->

## Backers

### Maintainers

These amazing people are maintaining this project:

- Benjamin Lupton <b@lupton.cc> (https://github.com/balupton)

### Sponsors

No sponsors yet! Will you be the first?

[![Gratipay donate button](https://img.shields.io/gratipay/bevry.svg)](https://www.gratipay.com/bevry/ "Donate weekly to this project using Gratipay")
[![Flattr donate button](https://img.shields.io/badge/flattr-donate-yellow.svg)](http://flattr.com/thing/344188/balupton-on-Flattr "Donate monthly to this project using Flattr")
[![PayPayl donate button](https://img.shields.io/badge/paypal-donate-yellow.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=QB8GQPZAH84N6 "Donate once-off to this project using Paypal")
[![BitCoin donate button](https://img.shields.io/badge/bitcoin-donate-yellow.svg)](https://coinbase.com/checkouts/9ef59f5479eec1d97d63382c9ebcb93a "Donate once-off to this project using BitCoin")
[![Wishlist browse button](https://img.shields.io/badge/wishlist-donate-yellow.svg)](http://amzn.com/w/2F8TXKSNAFG4V "Buy an item on our wishlist for us")

### Contributors

These amazing people have contributed code to this project:

- [Benjamin Lupton](https://github.com/balupton) <b@lupton.cc> — [view contributions](https://github.com/bevry/feedr/commits?author=balupton)
- [Zearin](https://github.com/Zearin) — [view contributions](https://github.com/bevry/feedr/commits?author=Zearin)

[Become a contributor!](https://github.com/bevry/feedr/blob/master/CONTRIBUTING.md#files)

<!-- /BACKERS -->


<!-- LICENSE/ -->

## License

Unless stated otherwise all works are:

- Copyright &copy; 2012+ Bevry Pty Ltd <us@bevry.me> (http://bevry.me)

and licensed under:

- The incredibly [permissive](http://en.wikipedia.org/wiki/Permissive_free_software_licence) [MIT License](http://opensource.org/licenses/mit-license.php)

<!-- /LICENSE -->


