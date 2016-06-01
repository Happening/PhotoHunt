
Colors = App.colors()
tr = I18n.tr

exports.renderSettings = !->
	unless Db.shared? # install only option
		Form.box !->
			opts =
				'EN': tr("English")
				'NL': tr("Dutch")
				'ES': tr("Spanish")
				'FR': tr("French")
				'DE': tr("German")
				'IT': tr("Italian")

			def = if !!App.userLanguage and (uLang = App.userLanguage().substring(0, 2).toUpperCase()) and opts[uLang]
				uLang
			else
				'EN'
			langO = Obs.create def

			[handleChange] = Form.makeInput
				name: 'language'
				value: langO.peek()

			Dom.text tr("Language")
			Dom.div !->
				Dom.style fontSize: '75%'
				Dom.text opts[langO.get()]

			Dom.onTap !->
				Modal.show tr("Language"), !->
					for lanCode, lanName of opts then do (lanCode, lanName) !->
						Ui.item !->
							Dom.text lanName
							if langO.peek() is lanCode
								Dom.style fontWeight: 'bold'

								Dom.div !->
									Dom.style
										Flex: 1
										textAlign: 'right'
										fontSize: '150%'
										color: App.colors().highlight
									Dom.text "✓"
							Dom.onTap !->
								handleChange lanCode
								langO.set lanCode
								Modal.remove()

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

	if App.users.count().get() < 2 and !App.hasLinkedGroup?()
		Dom.div !->
			Dom.style
				position: 'relative'
				marginTop: '20px'
				marginBottom: '20px'
				padding: '10px'
				borderRadius: '10px'
				backgroundColor: '#ddd'
				textAlign: 'center'
			Dom.div !->
				Dom.style
					position: 'absolute'
					content: '""'
					top: '-20px'
					left: '60px'
					marginLeft: '-10px'
					border: '10px solid transparent'
					borderBottom: '10px solid #ddd'
			Dom.userText tr("Start here. People you add can join the fun without installing anything!")
	else
		Ui.top !->
			Dom.style margin: 0

			Form.label !->
				Dom.style textAlign: 'center', fontSize: '140%', marginBottom: '10px'
				Dom.text tr "Top hunters"

			# Last week | All time | You...?

			showMore = Obs.create false

			Obs.observe !->
				sorted = (+k for k, v of rankings.get() when +k).sort (a, b) -> rankings.get(b) - rankings.get(a)
				points = pos = 0
				loop
					Dom.div !->
						Dom.style Box: true
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
								Ui.avatar App.userAvatar(userId),
									size: 80
									onTap: !->
										App.showMemberInfo(uiUid)
								Dom.div !->
									Dom.style margin: '4px', textAlign: 'center'
									Dom.text App.userName(userId)
									Dom.div !->
										Dom.style fontSize: '75%'
										Dom.text tr("%1 points", points)
					pos += 3
					break if !points or !sorted[pos] or !showMore.get()

				if sorted[3] and rankings.get(sorted[3]) and !showMore.get()
					Dom.div !->
						Dom.style padding: '8px', borderRadius: '2px', textAlign: 'center'
						Dom.addClass 'link'
						Dom.text tr("Show all hunters...", rankings.get(App.userId())||0)
						Dom.onTap !-> showMore.set true

	Obs.observe !->
		# next hunt
		next = Db.shared.get 'next'
		Ui.item !->
			Dom.div !->
				Dom.style Box: 'center middle', Flex: true
				Dom.div !->
					Dom.style width: '70px', height: '70px', marginRight: '10px', marginLeft: '-4px', Box: 'center middle'
					Icon.render data: 'clock2', color: '#aaa', style: { display: 'block' }, size: 34
				if +next is 1
					Dom.div tr("No more hunts available, we will let you know when new ones have been added...")
				else
					Dom.div !->
						Dom.style Flex: true
						Dom.div tr("A new hunt will start")
						Dom.div !->
							Dom.style fontSize: '120%', fontWeight: 'bold'
							if next
								Time.deltaText next
							else
								Dom.text tr("after one other participant joins")
					Dom.onTap !->
						require('modal').show tr("New hunt"), tr("A new hunt will normally appear daily, unless the app owner or an admin starts one manually")
			if +next isnt 1 and (App.userId() is App.ownerId() or App.userIsAdmin())
				Dom.div !->
					Dom.style borderLeft: '1px solid #ccc', padding: '10px 14px'
					Icon.render data: 'fastforward'
					Dom.onTap !->
						require('modal').confirm tr("Start new hunt now?"), tr("The app owner and/or admin can start a new round. Use it when all hunters want to continue to the next round."), !->
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
							marginLeft: '-4px'
							background: "url(#{Photo.url key, 200}) 50% 50% no-repeat"
							backgroundSize: 'cover'
					Dom.div !->
						Dom.style Flex: 1, fontSize: '120%'
						Dom.text hunt.get('subject')
						if hunt.get('winner')
							Dom.div !->
								Dom.style fontSize: '75%', marginTop: '6px'
								Dom.text tr("%1 won!", App.userName(hunt.get('photos', hunt.get('winner'), 'userId')))
								if (cnt = hunt.count('photos').get()-2)
									Dom.text ' (' + tr("%1 |runner-up|runners-up", cnt) + ')'

				else
					showAsNewest = +hunt.key() is +Db.shared.get('hunts', 'maxId') #and App.created() isnt hunt.get('time')
					Dom.div !->
						Dom.style width: '70px', height: '70px', marginRight: '10px', marginLeft: '-4px', Box: 'center middle'
						Icon.render
							data: (if showAsNewest then 'new' else 'warn')
							style: { display: 'block' }
							size: 34
							color: (if showAsNewest then (if Event.isNew(hunt.get('time')) then '#5b0' else Colors.highlight) else '#aaa')
					Dom.div !->
						Dom.style Flex: 1, fontSize: '120%'
						if showAsNewest
							Dom.text switch Db.shared.get('language')
								when 'NL' then "Neem een foto van jezelf..."
								when 'ES' then "Sácate una foto..."
								when 'FR' then "Prenez une photo de vous..."
								when 'DE' then "Mach ein Foto von dir, während du..."
								when 'IT' then "Scattati una foto..."
								else "Take a photo of you..."

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
				[-hunt.get('time'), -hunt.key()]

getUploading = (huntId) ->
	if uploads = Photo.uploads.get()
		for key, upload of uploads
			return upload if +upload.localId is +huntId

renderRoundedHeader = (text, isNew) !->
	Dom.h3 !->
		color = if isNew then '#5b0' else '#0077cf'
		Dom.style
			textAlign: 'center'
			color: color
			margin: '2px'
			padding: '6px 4px 4px 4px'
			border: '2px solid #ddd'
			borderBottom: 'none'
			borderRadius: '10px 10px 0 0'
		Dom.text text

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
			Ui.spinner
				size: 24
				content: !->
					Dom.style margin: '5px'
				light: true

renderPhotoThumb = (huntId, winnerId, photo, boxSize) !->
	isWinner = +photo.key() is winnerId
	if isWinner
		width = Page.width() - 8
		height = 0.8 * Page.height()
		width = Math.min(width, height)
	else
		width = boxSize.get()
	Dom.div !->
		Dom.cls 'photo'
		Dom.style
			display: 'inline-block'
			margin: '2px'
			position: 'relative'
			height: width + 'px'
			width: width + 'px'
			backgroundImage: Photo.css photo.get('key'), (if isWinner then 800 else 200)
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
				Comments.renderLike
					store: ['likes', huntId+'-p'+photo.key()]
					userId: photo.get('userId')
					noExpand: true
					aboutWhat: tr("photo")
					color: '#fff'

			Ui.avatar App.userAvatar(photo.get('userId')),
				size: 28
				style: margin: 0
				onTap: !-> App.showMemberInfo(photo.get('userId'))

		Dom.onTap !->
			Page.nav {0: huntId, 1: +photo.key(), return: true}

renderFullScreen = (huntId, winnerId, photoId) !->
	(require 'photoview').render
		current: photoId
		idToPhotoKey: (id) ->
			Db.shared.get('hunts', huntId, 'photos', id, 'key')
		getNeighbourIds: (id) ->
			photos = Db.shared.ref('hunts', huntId, 'photos')
			maxId = photos.peek('maxId')
			left = id-1
			while (!photos.isHash(left) or left is winnerId) and left > 0
				left--

			right = +id+1
			if winnerId
				if !left
					left = winnerId # winner is the photo most to the left
				if id is winnerId
					right = 0 # start searching for the first runner-up from the beginning

			while (!photos.isHash(right) or right is winnerId) and right <= maxId
				right++
			left = undefined if !photos.isHash(left) or +id is winnerId
			right = undefined if !photos.isHash(right)
			[left, right]
		fullHeight: true
		content: (pId) !->
			photo = Db.shared.ref('hunts', huntId, 'photos', pId)
			showDisqualify = (App.userId() is App.ownerId() or App.userIsAdmin()) and pId is winnerId
			setActionButton huntId, pId, showDisqualify
			Dom.style backgroundColor: (if pId then '#000' else '#fff'), position: 'relative'
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
				isNew = Event.isNew(photo.get('time'))
				pUserId = photo.get 'userId'
				Dom.div !->
					Dom.style textAlign: 'center', marginBottom: (if isNew then '8px' else '2px')
					Dom.h3 !->
						Dom.style
						padding: '2px 4px'
						borderRadius: '2px'
						color: if isNew then '#5b0' else '#ccc'
						backgroundColor: if isNew then '#fff' else ''
						display: 'inline'
						Dom.text (if pId isnt winnerId then tr("Runner-up by %1", App.userName(pUserId)) else tr("%1 won!", App.userName(pUserId)))

				Dom.span !->
					Dom.style fontSize: '85%', fontWeight: 'bold', whiteSpace: 'nowrap'
					Comments.renderLike
						store: ['likes', huntId+'-p'+pId]
						userId: pUserId
						aboutWhat: tr("photo")
						noExpand: true
						color: '#fff'


setActionButton = (huntId, photoId, showDisqualify) !->
	Page.setActions
		icon: if showDisqualify then 'warn' else 'delete'
		action: !->
			if showDisqualify
				question = tr "Remove, or disqualify photo?"
				options = ['cancel', tr("Cancel"), 'remove', tr("Remove"), 'disqualify', tr("Disqualify")]
			else
				question = tr "Remove photo?"
				options = ['cancel', tr("Cancel"), 'ok', tr("OK")]

			require('modal').show null, question, (option) !->
				if option isnt 'cancel'
					Server.sync 'removePhoto', huntId, photoId, (option is 'disqualify'), !->
						Db.shared.remove 'hunts', huntId, 'winner'
						if option is 'disqualify'
							Db.shared.set 'hunts', huntId, 'photos', photoId, 'disqualified', true
						else
							Db.shared.remove 'hunts', huntId, 'photos', photoId
					if photoId # don't navigate back from winner page
						Page.back()
			, options


renderHunt = (huntId, photoId) !->
	subject = Db.shared.get('hunts', huntId, 'subject')
	Page.setTitle subject

	winnerId = +Db.shared.get 'hunts', huntId, 'winner'
	photos = Db.shared.ref 'hunts', huntId, 'photos'
	if photoId
		mainPhoto = photos.ref photoId
	else
		mainPhoto = photos.ref winnerId

	# remove button
	if (photoId or winnerId) and (mainPhoto.get('userId') is App.userId() or App.userIsAdmin() or App.userId() is App.ownerId())
		showDisqualify = (App.userId() is App.ownerId() or App.userIsAdmin()) and +mainPhoto.key() is winnerId
		setActionButton huntId, mainPhoto.key(), showDisqualify

	# single submission fullscreen
	if photoId
		renderFullScreen huntId, winnerId, +mainPhoto.key()
		return

	boxSize = Obs.create()
	Obs.observe !->
		width = Page.width()
		cnt = (0|(width / 150)) || 1
		boxSize.set(0|(width-((cnt+1)*4))/cnt)

	allowUpload = Obs.create(true) # when the current user has no photos yet, allow upload
	Db.shared.observeEach 'hunts', huntId, 'photos', (photo) !->
		return if +photo.get('userId') isnt App.userId()
		allowUpload.set false
		Obs.onClean !->
			allowUpload.set true


	

	# winner photo area
	Dom.div !->
		Dom.style margin: 0
		if mainPhoto and mainPhoto.key()
			Dom.div !->
				Dom.style textAlign: 'center', padding: '2px', marginBottom: '4px'
				renderRoundedHeader tr("%1 won! (10 points)", App.userName(mainPhoto.get('userId'))), Event.isNew(mainPhoto.get('time'))
				renderPhotoThumb huntId, winnerId, mainPhoto, boxSize # big thumb!
		else
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

		if Db.personal.get('seen', 'hunt2') is 'Group' and !!App.newGroup
			seenExperiment = !->
				Server.sync 'seenExp', 'hunt2', true, !->
					Db.personal.set 'seen', 'hunt2', true
			Dom.div !->
				Dom.style border: '2px solid #ddd', borderRadius: '10px', margin: '4px', padding: '8px', textAlign: 'center'
				Dom.userText tr("Well done! 👍  Is there any other group of people you'd also like to play this with?")
				Ui.bigButton !->
					Dom.style margin: '16px 0 8px 0'
					Dom.text tr("Start new group")
				, !->
					App.newGroup()
					seenExperiment()

				Ui.lightButton tr("Not interested"), !->
					seenExperiment()

		photos = Db.shared.ref 'hunts', huntId, 'photos'
		# do we have a winner, or runner-ups?
		if winnerId or photos.count().get()>(1 + if winnerId then 1 else 0)
			Dom.div !->
				Dom.style padding: '2px', textAlign: 'center', marginBottom: '8px'

				hasNew = Obs.create false
				Obs.observe !->
					renderRoundedHeader tr("Runners-up (2 points)"), hasNew.get()

				# runner-ups thumbs
				photos.observeEach (photo) !->
					if Event.isNew(photo.get('time'))
						hasNew.set true
					renderPhotoThumb huntId, winnerId, photo, boxSize
				, (photo) ->
					if (id = +photo.key()) and id isnt winnerId
						id

				if upload = getUploading(huntId)
					renderUploading upload, boxSize
				else if allowUpload.get() and winnerId
					addPhoto boxSize.get()-4, huntId
				else if photos.count().get()<=(1 + if winnerId then 1 else 0) # maxId is also counted
					Dom.div !->
						Dom.style padding: '6px 2px', color: '#aaa'
						Dom.text tr "No runners-up submitted"

	# Messages
	Dom.div !->
		Dom.style padding: '2px', margin: 0
		renderRoundedHeader tr("Messages")

	Comments.inline
		inlineHeader: false
		messages:
			runnerUp: (c) -> tr("%1 added a runner-up", c.user)
			winner: (c) -> tr("%1 won!", c.user)
			disqualify: (c) -> tr("%1 disqualified photo by %2", c.user, App.userName(c.a))
			winnerAfterDisqualify: (c) -> tr("%1 disqualified photo by %2, making %3 the new winner!", c.user, App.userName(c.a), App.userName(c.w))
			retract: (c) -> tr("%1 retracted photo", c.user)
			winnerAfterRetract: (c) -> tr("%1 retracted photo, making %2 the new winner!", c.user, App.userName(c.w))
			remove: (c) -> tr("%1 removed photo by %2", c.user, App.userName(c.a))
			winnerAfterRemove: (c) -> tr("%1 removed photo by %2, making %3 the new winner!", c.user, App.userName(c.a), App.userName(c.w))
		legacyStore: huntId

addPhoto = (size, huntId) !->
	Dom.div !->
		Dom.cls 'add'
		Dom.style
			display: 'inline-block'
			position: 'relative'
			verticalAlign: 'top'
			margin: '2px'
			background:  "url(#{App.resourceUri('addphoto.png')}) 50% 50% no-repeat"
			backgroundSize: '32px'
			border: 'dashed 2px #aaa'
			height: size + 'px'
			width: size + 'px'
		Dom.onTap !->
			Photo.pick 'camera', [huntId], huntId
			if !!App.trackUserExperiment and Db.shared.get('hunts', 'maxId')>=10
				exp = App.trackUserExperiment 'hunt2', [false, 'Group']
				if exp is 'Group' and !Db.personal.get('seen', 'hunt2')?
					Server.sync 'seenExp', 'hunt2', 'Group', !-> # enable experiment
						Db.personal.set 'seen', 'hunt2', 'Group'


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
