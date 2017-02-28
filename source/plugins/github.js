'use strict'

module.exports.check = function checkGitHub ({feed, data}, next) {
	if ( feed.url.indexOf('github.com') !== -1 && data && data.message ) {
		return next(new Error(data.message))
	}
	return next()
}
