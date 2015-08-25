if ( process.env.REQUIRE_ES6 ) {
	module.exports = require('./es6/lib/feedr.js')
}
else {
	try {
		module.exports = require('./es6/lib/feedr.js')
	}
	catch (e) {
		// console.error('Downgrading from ES6 to ES5 due to:', e.stack)
		module.exports = require('./es5/lib/feedr.js')
	}
}
