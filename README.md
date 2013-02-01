# Feedr [![Build Status](https://secure.travis-ci.org/bevry/feedr.png?branch=master)](http://travis-ci.org/bevry/feedr)

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

// Create our Feedr instance, we can pass optional configuration to it here if we wanted
feedr = new Feedr();

// Prepare our feeds that we want read
feeds = {
	github: {
		url: "https://github.com/bevry/feedr/commits/master.atom"
	},
	twitter: {
		url: "https://api.twitter.com/1/statuses/user_timeline.json?screen_name=balupton&count=20&include_entities=true&include_rts=true"
	}
};

// Read our feeds and return the result
feedr.readFeeds(feeds, function(err,result){
	console.log(err,result.github,result.twitter);
});
```


## Configuration

- `log: null` our log function to use
- `logError: null` our error log function to use
- `tmpPath: null` the tempory path to cache our feedr results to (will autodetect if `null`)
- `cache: true` whether or not we should cache the results
- `cacheTime: 1000*60*5` how long should the cache stay active in milliseconds
- `timeout: 10*1000` how long should we wait before aborting the request in milliseconds
- `xmljsOptions: null` what options should we pass to [xml2js](https://github.com/Leonidas-from-XIV/node-xml2js) (can be a string which will reference to `xml2js.defaults`)



## History

You can discover the history inside the `History.md` file


## License

Licensed under the [MIT License](http://creativecommons.org/licenses/MIT/)
<br/>Copyright &copy; 2012+ [Bevry Pty Ltd](http://bevry.me)