Timer = require 'timer'
Plugin = require 'plugin'
Db = require 'db'
Event = require 'event'

exports.onInstall = (config) !->
	newHunt()

exports.onUpgrade = !->
	# keep 'm coming!
	if Db.shared.get('next') < Plugin.time()
		newHunt()

exports.client_newHunt = exports.newHunt = newHunt = ->
	log 'newHunt called'
	hunts = [
		"Holding a cat",
		"Brushing your teeth",
		"Riding a bike",
		"Getting a kiss",
		"Wearing a cap",
		"And a police officer",
		"Drinking a glass of beer",
		"With a store mannequin",
		"In a children's ride",
		"Giving someone a piggy-back ride",
		"With someone wearing the same shirt",
		"In an elevator",
		"Licking an ice cream",
		"Hugging a stuffed animal",
		"In front of a pub",
		"Wearing yellow sunglasses",
		"Wearing ski goggles",
		"Eating a carrot",
		"Smoking a cigar",
		"And one of your parents",
		"In front of a fire",
		"Among dancing people"
	]

	# remove hunts that have taken place already
	if prevHunts = Db.shared.get('hunts')
		for huntId, hunt of prevHunts
			continue if !+huntId
			if (pos = hunts.indexOf(hunt.subject))?
				hunts.splice pos, 1

	if hunts.length
		newPos = Math.floor(Math.random()*hunts.length)

		maxId = Db.shared.incr 'hunts', 'maxId'
		log 'maxId', maxId
		Db.shared.set 'hunts', maxId,
			subject: hunts[newPos]
			time: 0|(Date.now()*.001)
			photos: {}

		if hunts.length>1
			tomorrowStart = Math.floor(Plugin.time()/86400)*86400 + 86400
			nextTime = tomorrowStart + (10*3600) + Math.floor(Math.random()*(12*3600)) 
			Timer.cancel()
			Timer.set (nextTime-Plugin.time())*1000, 'newHunt'
			Db.shared.set 'next', nextTime

		subj = hunts[newPos]
		Event.create
			unit: 'hunts'
			text: "New Photo Hunt: Take a photo of you.. " + subj.charAt(0).toLowerCase() + subj.slice(1)

exports.client_removePhoto = (huntId, photoId) !->
	photos = Db.shared.ref 'hunts', huntId, 'photos'
	if photos.get photoId
		photos.remove photoId

	# find a new winner if necessary
	if Db.shared.get('hunts', huntId, 'winner') is photoId
		smId = (+k for k of photos.get())?.sort()[0]
		Db.shared.set 'hunts', huntId, 'winner', smId
		if smId
			Event.create
				unit: 'hunts'
				text: "Photo Hunt: "+Plugin.userName(photos.get smId, 'userId')+" won! ("+Db.shared.get('hunts', huntId, 'subject')+")"

exports.onPhoto = (info, huntId) !->
	huntId = huntId[0]
	log 'got photo', JSON.stringify(info), Plugin.userId()

	###
	# implement count function in lib-db.backend.coffee
	log 'huntId', huntId
	hunt = Db.shared.ref 'hunts', huntId
	maxId = hunt.incr 'photos', 'maxId'
	hunt.set 'photos', maxId, info
	log 'hunt now', JSON.stringify(hunt.get())

	if hunt.count('photos').get() <= 1
		log 'winning!'
		hunt.set 'winner', maxId
	###
	
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
