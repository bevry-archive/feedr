# Feedr

[![Build Status](https://secure.travis-ci.org/bevry/feedr.png?branch=master)](http://travis-ci.org/bevry/feedr)
[![NPM version](https://badge.fury.io/js/feedr.png)](https://npmjs.org/package/feedr)
[![Flattr this project](https://raw.github.com/balupton/flattr-buttons/master/badge-89x18.gif)](http://flattr.com/thing/344188/balupton-on-Flattr)

Feedr takes in a remote feed (regardless of format type) and converts it into JSON data



## Install

```
npm install --save feedr
```



## Usage

``` javascript
// Prepare
var Feedr, feedr, feeds;

// Include the Feedr Class
Feedr = require('feedr').Feedr;

// Create our Feedr instance, we can pass optional configuration if we wanted
feedr = new Feedr();

// Prepare our feeds that we want read
feeds = {
	github: "https://github.com/bevry/feedr/commits/master.atom",
	twitter: "https://api.twitter.com/1/statuses/user_timeline.json?screen_name=balupton&count=20&include_entities=true&include_rts=true"
};

// Read a single feed
feedr.readFeed(feeds.github, function(err, data, headers){
	console.log(err, data, headers);
});

// Read all the feeds together
feedr.readFeeds(feeds, function(err, result){
	console.log(err, result.github, result.twitter);
});
```



## Configuration

Global configuration properties are:

- `log` defaults to `null`, log function to use
- `tmpPath` defaults to system tmp path, the tempory path to cache our feedr results to
- `cache` defaults to `true`, whether or not we should use the cache if it is valid
- `xml2jsOptions` defaults to `null`, the options to send to [xml2js](https://github.com/Leonidas-from-XIV/node-xml2js)
- `requestOptions` defaults to `null`, the options to send to [request](https://github.com/mikeal/request)

Feed configuration properties are:

- `url` required, the url to fetch
- `hash` defaults to hash of the url, the hashed url for caching
- `name` defaults to hash, the name of the feed for use in debugging
- `path` defaults to tmp feed path, the path to save the file to
- `checkResponse` defaults to `null`, a function accepting `response`, `data`, and `next` to check the response for errors
- `xml2jsOptions` defaults to global value, the options to send to [xml2js](https://github.com/Leonidas-from-XIV/node-xml2js)
- `requestOptions` defaults to global value, the options to send to [request](https://github.com/mikeal/request)


## History
You can discover the history inside the `History.md` file



## License
Licensed under the [MIT License](http://creativecommons.org/licenses/MIT/)
<br/>Copyright &copy; 2012+ [Bevry Pty Ltd](http://bevry.me)