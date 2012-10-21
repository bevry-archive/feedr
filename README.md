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


## History

You can discover the history inside the `History.md` file


## License

Licensed under the [MIT License](http://creativecommons.org/licenses/MIT/)
<br/>Copyright &copy; 2012 [Bevry Pty Ltd](http://bevry.me)