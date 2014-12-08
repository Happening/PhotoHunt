Timer = require 'timer'
Plugin = require 'plugin'
Db = require 'db'
Event = require 'event'

exports.onInstall = (config) !->
	newHunt(3) # we'll start with 3 subjects
	Event.create
		unit: 'hunts'
		text: "New Photo Hunt: earn points by completing the various hunts!"

exports.onUpgrade = !->
	# apparently a timer did not fire, correct it
	if Db.shared.get('next') < Plugin.time()
		newHunt()

exports.client_newHunt = exports.newHunt = newHunt = (amount = 1) !->
	log 'newHunt called, amount '+amount
	hunts = [
		"Brushing your teeth",
		"Riding a bike",
		"Kissing someone",
		"Wearing a cap",
		"And a police officer",
		"Drinking a glass of beer",
		"With a store mannequin",
		"Sitting on a swing",
		"Carrying someone",
		"With someone wearing the same shirt",
		"In an elevator",
		"Eating an ice cream",
		"Hugging a stuffed animal",
		"Wearing yellow sunglasses",
		"Wearing ski goggles",
		"Smoking a cigar",
		"And one of your parents",
		"With whipped cream on your face",
		"Blowing bubble gum",
		"Lying on the street"
	]

	# remove hunts that have taken place already
	if prevHunts = Db.shared.get('hunts')
		for huntId, hunt of prevHunts
			continue if !+huntId
			if (pos = hunts.indexOf(hunt.subject))?
				hunts.splice pos, 1

	# find some new hunts
	newHunts = []
	while amount-- and hunts.length
		sel = Math.floor(Math.random()*hunts.length)
		newHunts.push hunts[sel]
		hunts.splice sel, 1

	log 'selected new hunts: '+JSON.stringify(newHunts)

	for newHunt in newHunts
		maxId = Db.shared.ref('hunts').incr 'maxId'
			# first referencing hunts, as Db.shared.incr 'hunts', 'maxId' is buggy
		Db.shared.set 'hunts', maxId,
			subject: newHunt
			time: 0|(Date.now()*.001)
			photos: {}

		# schedule the next hunt when there are still hunts left
		if hunts.length
			tomorrowStart = Math.floor(Plugin.time()/86400)*86400 + 86400
			nextTime = tomorrowStart + (10*3600) + Math.floor(Math.random()*(12*3600))
			Timer.cancel()
			Timer.set (nextTime-Plugin.time())*1000, 'newHunt'
			Db.shared.set 'next', nextTime

	# we'll only notify when this is about a single new hunt
	if newHunts.length is 1
		subj = newHunts[0]
		Event.create
			unit: 'hunts'
			text: "New Photo Hunt: take a photo of you.. " + subj.charAt(0).toLowerCase() + subj.slice(1)

exports.client_removePhoto = (huntId, photoId, disqualify = false) !->
	photos = Db.shared.ref 'hunts', huntId, 'photos'
	if photos.get photoId
		if disqualify
			photos.set photoId, 'disqualified', true
			addComment huntId, "disqualified the photo added by " + Plugin.userName(photos.get photoId, 'userId')
		else
			photoOwner = photos.get photoId, 'userId'
			if Plugin.userId() isnt photoOwner
				addComment huntId, "removed the photo added by " + Plugin.userName(photoOwner)
			photos.remove photoId

	# find a new winner if necessary
	if Db.shared.get('hunts', huntId, 'winner') is photoId
		smId = (+k for k, v of photos.get() when !v.disqualified)?.sort()[0]
		Db.shared.set 'hunts', huntId, 'winner', smId
		if smId
			Event.create
				unit: 'hunts'
				text: "Photo Hunt: results revised, "+Plugin.userName(photos.get smId, 'userId')+" won! ("+Db.shared.get('hunts', huntId, 'subject')+")"

exports.onPhoto = (info, huntId) !->
	huntId = huntId[0]
	log 'got photo', JSON.stringify(info), Plugin.userId()

	# test whether the user hasn't uploaded a photo in this hunt yet
	allPhotos = Db.shared.get 'hunts', huntId, 'photos'
	for k, v of allPhotos
		if +v.userId is Plugin.userId()
			log "user #{Plugin.userId()} already submitted a photo for hunt "+huntId
			return

	hunt = Db.shared.ref 'hunts', huntId
	maxId = hunt.incr 'photos', 'maxId'
	hunt.set 'photos', maxId, info
	if !hunt.get 'winner'
		hunt.set 'winner', maxId
		Event.create
			unit: 'hunts'
			text: "Photo Hunt: "+Plugin.userName()+" won! ("+hunt.get('subject')+")"
	else
		addComment huntId, "added a runner-up"

addComment = (huntId, comment) !->
	comment =
		t: 0|Plugin.time()
		u: Plugin.userId()
		s: true
		c: comment

	comments = Db.shared.createRef("comments", huntId)
	max = comments.incr 'max'
	comments.set max, comment
