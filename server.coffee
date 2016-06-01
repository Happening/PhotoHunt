setLanguage = (lang) !->
	lang ||= Db.shared.get('language')
	if lang not in ['EN', 'NL', 'ES', 'FR', 'DE', 'IT']
		lang = 'EN'
	Db.shared.set 'language', lang
	log "Hunts language set to", lang

exports.onInstall = (config) !->
	setLanguage config.language||false
	newHunt(3) # we'll start with 3 subjects

exports.onUpgrade = !->
	# upgrade to multi language
	setLanguage()

	# apparently a timer did not fire (or we were out of hunts, next -> 1), correct it
	if 0 < Db.shared.get('next') < App.time()
		Timer.set(Math.floor(Math.random()*7200*1000), 'newHunt')

scheduleNextHunt = (delayDays) !->
	if !delayDays?
		delayDays = 1
		maxId = Db.shared.get 'hunts', 'maxId'
		if maxId>7
			openHunts = 0
			deltaTime = false
			for i in [maxId...maxId-7]
				if Db.shared.get 'hunts', i, 'photos', 'maxId'
					break # a photo was posted
				if i>1
					deltaTime = Db.shared.get('hunts', i, 'time') - Db.shared.get('hunts', i-1, 'time')
				if deltaTime is false or deltaTime>10*60*60 # probably not manually triggered, count it
					openHunts++

			if openHunts > 2 # at least 3 consecutive open hunts
				delayDays = Math.pow(openHunts - 2, 2) # 1, 4, 9, 16, 25 days delay

	now = App.time()
	nextDayStart = Math.floor(now/86400)*86400 + Math.max(1, delayDays)*86400 + ((new Date).getTimezoneOffset() * 60)
	nextTime = nextDayStart + (10*3600) + Math.floor(Math.random()*(12*3600))
	if (nextTime-now) > 3600
		Timer.cancel()
		Timer.set (nextTime-now)*1000, 'newHunt'
		Db.shared.set 'next', nextTime


exports.onJoin = !->
	if App.userIds().length > 1 and !Db.shared.get('next')?
		scheduleNextHunt()


exports.client_newHunt = exports.newHunt = newHunt = (amount = 1, cb = false) !->
	return if Db.shared.get('next') is -1
		# used to disable my plugins and master instances

	log 'newHunt called, amount '+amount
	hunts = require('hunts'+Db.shared.get('language')).hunts()

	# remove hunts that have taken place already
	if prevHunts = Db.shared.get('hunts')
		for huntId, hunt of prevHunts
			continue if !+huntId
			if (pos = hunts.indexOf(hunt.subject)) >= 0
				hunts.splice pos, 1

	# find some new hunts
	newHunts = []
	while amount-- and hunts.length
		sel = Math.floor(Math.random()*hunts.length)
		newHunts.push hunts[sel]
		hunts.splice sel, 1

	if !newHunts.length
		log 'no more hunts available'
		Db.shared.set 'next', 1 # shows 'no more hunts for now'
		if cb
			cb.reply true
	else
		log 'selected new hunt(s): '+JSON.stringify(newHunts)

		now = App.time()
		for newHunt in newHunts
			maxId = Db.shared.ref('hunts').incr 'maxId'
				# first referencing hunts, as Db.shared.incr 'hunts', 'maxId' is buggy
			Db.shared.set 'hunts', maxId,
				subject: newHunt
				time: 0|now
				photos: {}

		# schedule the next hunt when there are still hunts left (and multiple participants)
		if hunts.length and App.userIds().length > 1
			scheduleNextHunt (if cb then 1 else null) # always 1 when manually triggered by user

		# we'll only notify when this is about a single new hunt
		if newHunts.length is 1
			subj = newHunts[0]
			Event.create
				text: "New Photo Hunt: you " + subj.charAt(0).toLowerCase() + subj.slice(1)
				digest: false
				highPrio: true

exports.client_removePhoto = (huntId, photoId, disqualify = false) !->
	photos = Db.shared.ref 'hunts', huntId, 'photos'
	return if !photos.get photoId

	about = photos.get photoId, 'userId'
	thisUserSubmission = App.userId() is about

	if disqualify
		photos.set photoId, 'disqualified', true
	else
		photos.remove photoId

	# find a new winner if necessary
	newWinner = null
	if Db.shared.get('hunts', huntId, 'winner') is photoId
		smId = (+k for k, v of photos.get() when +k and !v.disqualified)?.sort()[0] || null
		Db.shared.set 'hunts', huntId, 'winner', smId # can also remove winner
		if smId
			newWinner = photos.get smId, 'userId'

	if disqualify
		if newWinner
			addComment huntId,
				u: App.userId()
				a: about
				w: newWinner
				s: 'winnerAfterDisqualify'
				highPrio: [about,newWinner]
		else
			addComment huntId,
				u: App.userId()
				a: about
				s: 'disqualify'
				highPrio: [about]
	else if thisUserSubmission
		if newWinner
			addComment huntId,
				u: App.userId()
				w: newWinner
				s: 'winnerAfterRetract'
				highPrio: [newWinner]
		else
			addComment huntId,
				u: App.userId()
				s: 'retract'
				lowPrio: true
	else if !thisUserSubmission
		if newWinner
			addComment huntId,
				u: App.userId()
				a: about
				w: newWinner
				s: 'winnerAfterRemove'
				highPrio: [about,newWinner]
		else
			addComment huntId,
				u: App.userId()
				a: about
				s: 'remove'
				highPrio: [about]

exports.client_seenExp = (exp, seen) !->
	Db.personal().set 'seen', exp, seen

exports.onPhoto = (info, huntId) !->
	huntId = huntId[0]
	log 'got photo', JSON.stringify(info), App.userId()

	# test whether the user hasn't uploaded a photo in this hunt yet
	allPhotos = Db.shared.get 'hunts', huntId, 'photos'
	for k, v of allPhotos
		if +v.userId is App.userId()
			log "user #{App.userId()} already submitted a photo for hunt "+huntId
			return

	hunt = Db.shared.ref 'hunts', huntId
	maxId = hunt.incr 'photos', 'maxId'
	info.time = 0|App.time()
	hunt.set 'photos', maxId, info
	notifyText = ''
	if !hunt.get 'winner'
		hunt.set 'winner', maxId
		addComment huntId,
			u: App.userId()
			s: 'winner'
			pushText: App.userName() + ' won!'
	else
		addComment huntId,
			u: App.userId()
			s: 'runnerUp'
			pushText: App.userName() + ' added a runner-up'
			lowPrio: true

addComment = (huntId, comment) !->
	if comment.pushText
		comment.pushText += ' (' + Db.shared.get('hunts', huntId, 'subject') + ')'
	comment.legacyStore = huntId
	comment.path = [huntId]
	Comments.post comment
