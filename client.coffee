Db = require 'db'
Dom = require 'dom'
Event = require 'event'
Form = require 'form'
Icon = require 'icon'
Loglist = require 'loglist'
Modal = require 'modal'
Obs = require 'obs'
Page = require 'page'
Photo = require 'photo'
Plugin = require 'plugin'
Server = require 'server'
Social = require 'social'
Time = require 'time'
Ui = require 'ui'

Colors = Plugin.colors()
{tr} = require 'i18n'

exports.render = !->
	if Page.state.get(0)
		renderHunt Page.state.get(0), Page.state.get(1)
			# when a second id is passed along that photo is rendered without other stuff around it
		return
	
	rankings = Obs.create()
	Db.shared.ref('hunts').observeEach (hunt) !->
		if hunt.get('winner')
			userWon = hunt.get('photos', hunt.get('winner'), 'userId')
			rankings.incr userWon, 10
			Obs.onClean !->
				rankings.incr userWon, -10

		hunt.observeEach 'photos', (photo) !->
			return if photo.get('userId') is userWon or !+photo.key()
			rankings.incr photo.get('userId'), 2
			Obs.onClean !->
				rankings.incr photo.get('userId'), -2

	#Obs.observe !->
	#	log 'rankings', rankings.get()

	Dom.h1 !->
		Dom.style textAlign: 'center', margin: '2px 0 6px 0'
		Dom.text tr "Top hunters"
	
	# Last week | All time | You...?
	
	showMore = Obs.create false

	Obs.observe !->
		sorted = (+k for k, v of rankings.get() when +k).sort (a, b) -> rankings.get(b) - rankings.get(a)
		points = pos = 0
		loop
			Dom.div !->
				Dom.style Box: true, padding: '4px 12px 0 12px'
				if !sorted.length
					Dom.div !->
						Dom.style Flex: 1, textAlign: 'center', padding: '10px'
						Dom.text tr("No photos have been submitted yet")

				for i in [0...3]
					break unless userId = sorted[pos+i]
					points = rankings.get(userId)
					Dom.div !->
						uiUid = userId
						Dom.style Box: 'center vertical', Flex: 1
						Ui.avatar Plugin.userAvatar(userId),
							size: 80
							onTap: !->
								Plugin.userInfo(uiUid)
						Dom.div !->
							Dom.style margin: '4px', textAlign: 'center'
							Dom.text Plugin.userName(userId)
							Dom.div !->
								Dom.style fontSize: '75%'
								Dom.text tr("%1 points", points)
			pos += 3
			break if !points or !sorted[pos] or !showMore.get()

		if sorted[3] and rankings.get(sorted[3]) and !showMore.get()
			Dom.div !->
				Dom.style padding: '8px', borderRadius: '2px', textAlign: 'center'
				Dom.addClass 'link'
				Dom.text tr("Show all hunters..", rankings.get(Plugin.userId())||0)
				Dom.onTap !-> showMore.set true

	Ui.list !->
		Dom.style marginTop: '4px'
		# next hunt
		next = Db.shared.get 'next'
		Ui.item !->
			Dom.div !->
				Dom.style Box: 'center middle', Flex: true
				Dom.div !->
					Dom.style width: '70px', height: '70px', marginRight: '10px', Box: 'center middle'
					Icon.render data: 'clock2', color: '#aaa', style: { display: 'block' }, size: 34
				if +next is 1
					Dom.div tr("No more hunts available, we will let you know when new ones have been added...")
				else
					Dom.div !->
						Dom.style Flex: true
						Dom.div tr("A new hunt will start")
						Dom.div !->
							Dom.style fontSize: '120%', fontWeight: 'bold'
							Time.deltaText next
					Dom.onTap !->
						require('modal').show tr("New hunt"), tr("A new hunt will normally appear daily, unless the group app owner or an admin starts one manually")
			if +next isnt 1 and (Plugin.userId() is Plugin.ownerId() or Plugin.userIsAdmin())
				Dom.div !->
					Dom.style borderLeft: '1px solid #ccc', padding: '10px 14px'
					Icon.render data: 'fastforward'
					Dom.onTap !->
						require('modal').confirm tr("Start new hunt now?"), tr("The group app owner and/or admin can start a new round. Use it when all hunters want to continue to the next round."), !->
							Server.call 'newHunt', 1


		Db.shared.observeEach 'hunts', (hunt) !->
			Ui.item !->
				winningPhoto = hunt.ref('photos', hunt.get('winner'))
				if key = winningPhoto.get('key')
					Dom.div !->
						Dom.style
							width: '70px'
							height: '70px'
							marginRight: '10px'
							background: "url(#{Photo.url key, 200}) 50% 50% no-repeat"
							backgroundSize: 'cover'
					Dom.div !->
						Dom.style Flex: 1, fontSize: '120%'
						Dom.text hunt.get('subject')
						if hunt.get('winner')
							Dom.div !->
								Dom.style fontSize: '75%', marginTop: '6px', color: (if Event.isNew(hunt.get('photos', hunt.get('winner'), 'time')) then '#5b0' else '')
								Dom.text tr("%1 won!", Plugin.userName(hunt.get('photos', hunt.get('winner'), 'userId')))
								if (cnt = hunt.count('photos').get()-2)
									Dom.text ' (' + tr("%1 |runner-up|runners-up", cnt) + ')'

				else
					showAsNewest = +hunt.key() is +Db.shared.get('hunts', 'maxId') and Plugin.created() isnt hunt.get('time')
					Dom.div !->
						Dom.style width: '70px', height: '70px', marginRight: '10px', Box: 'center middle'
						Icon.render
							data: (if showAsNewest then 'new' else 'warn')
							style: { display: 'block' }
							size: 34
							color: (if showAsNewest then (if Event.isNew(hunt.get('time')) then '#5b0' else Colors.highlight) else '#aaa')
					Dom.div !->
						Dom.style Flex: 1, fontSize: '120%'
						if showAsNewest
							Dom.text tr "Take a photo of you.."
							Dom.div !->
								Dom.style fontSize: '120%', fontWeight: 'bold', color: (if Event.isNew(hunt.get('time')) then '#5b0' else Colors.highlight)
								Dom.text hunt.get('subject')
						else
							Dom.text hunt.get('subject')
							Dom.div !->
								Dom.style fontSize: '75%', marginTop: '6px'
								Dom.text tr("Winner gets %1 points", 10)
								if (cnt = hunt.count('photos').get()-1) > 0
									Dom.text ' (' + tr("%1 disqualified |runner-up|runners-up", cnt) + ')'

				Event.renderBubble [hunt.key()], style: marginLeft: '4px'

				Dom.onTap !->
					Page.nav [hunt.key()]

		, (hunt) -> # skip the maxId key
			if +hunt.key()
				currentHunt = if +hunt.key() is +Db.shared.get('hunts', 'maxId') and !hunt.get('winner') then 0 else 1
				createTime = hunt.get('time')
				winnerTime = hunt.get('photos', hunt.get('winner'), 'time')||0
				orderTime = Event.getOrder([hunt.key()])
				[currentHunt, -Math.max(orderTime, winnerTime, createTime)]
				#[currentHunt, newWinnerTime, unreadCount, -hunt.key()]
				# -hunt.key() - 1000 * Event.getUnread([hunt.key()]) - 100000 * +Event.isNew(hunt.get('photos', hunt.get('winner'), 'time'))

getUploading = (huntId) ->
	if uploads = Photo.uploads.get()
		for key, upload of uploads
			return upload if +upload.localId is +huntId

renderUploading = (upload, boxSize) !->
	Dom.div !->
		Dom.div !->
			Dom.style
				margin: '2px'
				display: 'inline-block'
				Box: 'inline right bottom'
				height: boxSize.get() + 'px'
				width: boxSize.get() + 'px'
			if thumb = upload.thumb
				Dom.style
					background: "url(#{thumb}) 50% 50% no-repeat"
					backgroundSize: 'cover'
			Dom.cls 'photo'
			Ui.spinner 24, !->
				Dom.style margin: '5px'
			, 'spin-light.png'

renderHunt = (huntId, photoId) !->
	Dom.style padding: 0
	subject = Db.shared.get('hunts', huntId, 'subject')
	Page.setTitle subject
	Event.showStar subject

	winnerId = Db.shared.get 'hunts', huntId, 'winner'
	photos = Db.shared.ref 'hunts', huntId, 'photos'
	if photoId
		mainPhoto = photos.ref photoId
	else
		mainPhoto = photos.ref winnerId

	# remove button
	if (photoId or winnerId) and (mainPhoto.get('userId') is Plugin.userId() or Plugin.userIsAdmin() or Plugin.userId() is Plugin.ownerId())
		showDisqualify = (Plugin.userId() is Plugin.ownerId() or Plugin.userIsAdmin()) and mainPhoto.key() is winnerId
		Page.setActions
			icon: if showDisqualify then Plugin.resourceUri('icon-report-48.png') else 'trash'
			action: !->
				if showDisqualify
					question = tr "Remove, or disqualify photo?"
					options = ['cancel', tr("Cancel"), 'remove', tr("Remove"), 'disqualify', tr("Disqualify")]
				else
					question = tr "Remove photo?"
					options = ['cancel', tr("Cancel"), 'ok', tr("OK")]

				require('modal').show null, question, (option) !->
					if option isnt 'cancel'
						Server.sync 'removePhoto', huntId, mainPhoto.key(), (option is 'disqualify'), !->
							Db.shared.remove 'hunts', huntId, 'winner'
							if option is 'disqualify'
								photos.set mainPhoto.key(), 'disqualified', true
							else
								photos.remove(mainPhoto.key())
						if photoId # don't navigate back from winner page
							Page.back()
				, options

	boxSize = Obs.create()
	Obs.observe !->
		width = Dom.viewport.get('width')
		cnt = (0|(width / 150)) || 1
		boxSize.set(0|(width-((cnt+1)*4))/cnt)

	if !photoId
		allowUpload = Obs.create(true) # when the current use has no photos yet, allow upload
		Db.shared.observeEach 'hunts', huntId, 'photos', (photo) !->
			return if +photo.get('userId') isnt Plugin.userId()
			allowUpload.set false
			Obs.onClean !->
				allowUpload.set true
	
	Dom.div !->
		Dom.style backgroundColor: '#fff', borderBottom: '2px solid #ccc'
		# main photo
		contain = Obs.create false
		if mainPhoto and mainPhoto.key()
			photoUserId = mainPhoto.get 'userId'

			(require 'photoview').render
				key: mainPhoto.get('key')
				content: !->
					Dom.style backgroundColor: '#000', position: 'relative'
					Dom.div !->
						Dom.style
							position: 'absolute'
							bottom: 0
							left: 0
							right: 0
							textAlign: 'center'
							padding: '24px 8px 8px 8px'
							color: 'white'
							background_: 'linear-gradient(top, rgba(0, 0, 0, 0) 0px, rgba(0, 0, 0, 0.6) 100%)'
						Dom.h3 !->
							Dom.style color: '#ccc'
							Dom.text (if photoId then tr("Runner-up by %1", Plugin.userName(photoUserId)) else tr("%1 won!", Plugin.userName(photoUserId)))

						Dom.span !->
							Dom.style fontSize: '85%', fontWeight: 'bold', whiteSpace: 'nowrap'
							Social.renderLike
								path: [huntId]
								id: 'p'+mainPhoto.key()
								userId: photoUserId
								aboutWhat: tr("photo")
								noExpand: true
								color: '#fff'

		else if !photoId
			Dom.div !->
				Dom.style textAlign: 'center', padding: '16px'
				if upload = getUploading(huntId)
					renderUploading upload, boxSize
				else if allowUpload.get()
					addPhoto boxSize.get()-4, huntId
					Dom.div !->
						Dom.style textAlign: 'center', margin: '8px 0 16px 0'
						Dom.text tr 'The first one wins 10 points!'
				else
					Dom.text tr "You have already submitted a photo for this Hunt..."

		# we're only rendering other submissions and comments when it's the winner being displayed
		if !photoId
			photos = Db.shared.ref 'hunts', huntId, 'photos'
			# do we have a winner, or runner-ups?
			if winnerId or photos.count().get()>(1 + if winnerId then 1 else 0)
				Dom.div !->
					Dom.style padding: '2px', textAlign: 'center'

					Dom.h3 !->
						Dom.style
							color: '#fff'
							backgroundColor: '#ccc'
							margin: '2px'
							padding: '4px'
							borderRadius: '10px 10px 0 0'
						Dom.text tr "Runners-up (2 points)"

					photos.observeEach (photo) !->
						return if +photo.key() is winnerId
						Dom.div !->
							Dom.cls 'photo'
							Dom.style
								display: 'inline-block'
								margin: '2px'
								position: 'relative'
								height: (boxSize.get()) + 'px'
								width: (boxSize.get()) + 'px'
								backgroundImage: Photo.css photo.get('key'), 200
								backgroundSize: 'cover'
								backgroundPosition: '50% 50%'
								backgroundRepeat: 'no-repeat'

							Dom.div !->
								Dom.style
									position: 'absolute'
									bottom: 0
									left: 0
									right: 0
									Box: 'bottom'
									textAlign: 'left'
									padding: '24px 6px 6px 6px'
									color: 'white'
									background_: 'linear-gradient(top, rgba(0, 0, 0, 0) 0px, rgba(0, 0, 0, 0.6) 100%)'

								Dom.div !->
									Dom.style fontSize: '70%', marginBottom: '2px', fontWeight: 'bold', whiteSpace: 'nowrap', Flex: 1
									Social.renderLike
										path: [huntId]
										id: 'p'+photo.key()
										userId: photo.get('userId')
										noExpand: true
										aboutWhat: tr("photo")
										color: '#fff'

								Ui.avatar Plugin.userAvatar(photo.get('userId')),
									size: 28
									style: margin: 0, backgroundColor: 'white'
									onTap: !-> Plugin.userInfo(photo.get('userId'))

							Dom.onTap !->
								Page.nav [huntId, photo.key()]

					, (photo) ->
						if +photo.key()
							photo.key()

					if upload = getUploading(huntId)
						renderUploading upload, boxSize
					else if allowUpload.get() and winnerId
						addPhoto boxSize.get()-4, huntId
					else if photos.count().get()<=(1 + if winnerId then 1 else 0) # maxId is also counted
						Dom.div !->
							Dom.style padding: '6px 2px', color: '#aaa'
							Dom.text tr "No runners-up submitted"

	if !photoId
		Social.renderComments huntId, render: (comment) ->
			if comment.s and comment.u
				comment.c = Plugin.userName(comment.u) + ' ' + comment.c
				Dom.div !->
					Dom.style margin: '6px 0 6px 56px', fontSize: '70%'

					Dom.span !->
						Dom.style color: '#999'
						Time.deltaText comment.t
						Dom.text " • "

					Dom.text comment.c
				true # We're rendering these type of comments

addPhoto = (size, huntId) !->
	Dom.div !->
		Dom.cls 'add'
		Dom.style
			display: 'inline-block'
			position: 'relative'
			verticalAlign: 'top'
			margin: '2px'
			background:  "url(#{Plugin.resourceUri('addphoto.png')}) 50% 50% no-repeat"
			backgroundSize: '32px'
			border: 'dashed 2px #aaa'
			height: size + 'px'
			width: size + 'px'
		Dom.onTap !->
			Photo.pick 'camera', [huntId], huntId

Dom.css
	'.add.tap::after, .photo.tap::after':
		content: '""'
		display: 'block'
		position: 'absolute'
		left: 0
		right: 0
		top: 0
		bottom: 0
		backgroundColor: 'rgba(0, 0, 0, 0.2)'
