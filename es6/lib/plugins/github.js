export const check = function ({feed, data}, next) {
	if ( feed.url.indexOf('github.com') !== -1 && data && data.message ) {
		return next(new Error(data.message))
	}
	return next()
}
