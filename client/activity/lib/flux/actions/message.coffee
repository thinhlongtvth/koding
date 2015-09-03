_                      = require 'lodash'
kd                     = require 'kd'
whoami                 = require 'app/util/whoami'
actionTypes            = require './actiontypes'
generateFakeIdentifier = require 'app/util/generateFakeIdentifier'
messageHelpers         = require '../helpers/message'
realtimeActionCreators = require './realtime/actioncreators'
getGroup = require 'app/util/getGroup'

dispatch = (args...) -> kd.singletons.reactor.dispatch args...

###*
 * Action to load messages of channel with given channelId.
 *
 * @param {string} channelId
###
loadMessages = (channelId, options = {}) ->

  # if given channel is group channel, special case it for fetching activities
  # with comments.
  if getGroup().socialApiChannelId is channelId
    return loadPublicChannelMessages channelId, options

  options.limit ?= 25
  { socialapi } = kd.singletons
  { LOAD_MESSAGES_BEGIN, LOAD_MESSAGES_FAIL,
    LOAD_MESSAGES_SUCCESS, LOAD_MESSAGE_SUCCESS } = actionTypes

  dispatch LOAD_MESSAGES_BEGIN, { channelId }

  _options = _.assign {}, options, { id: channelId }

  socialapi.channel.fetchActivities _options, (err, messages) ->
    if err
      dispatch LOAD_MESSAGES_FAIL, { err, channelId }
      return

    dispatch LOAD_MESSAGES_SUCCESS, { channelId }

    kd.singletons.reactor.batch ->
      messages.forEach (message) ->
        dispatchLoadMessageSuccess channelId, message


###*
 * Loads public/group channel messages, with comments of them.
 *
 * @param {string} channelId
 * @param {object=} options
###
loadPublicChannelMessages = (channelId, options = {}) ->

  options.limit ?= 25
  { socialapi, reactor } = kd.singletons
  { LOAD_MESSAGES_BEGIN, LOAD_MESSAGES_FAIL,
    LOAD_MESSAGES_SUCCESS, LOAD_MESSAGE_SUCCESS } = actionTypes

  dispatch LOAD_MESSAGES_BEGIN, { channelId, options }

  _options = _.assign {}, options, { id: channelId }

  socialapi.channel.fetchActivitiesWithComments _options, (err, messages) ->
    if err
      dispatch LOAD_MESSAGES_FAIL, { err, channelId }
      return

    dispatch LOAD_MESSAGES_SUCCESS, { channelId, messages }

    kd.singletons.reactor.batch ->
      messages.forEach (message) ->
        if message.typeConstant is 'post'
          return dispatchLoadMessageSuccess channelId, message

        _messages = reactor.evaluate ['MessagesStore']
        parentMessage = _messages.get message.parentId
        if parentMessage
          dispatchLoadMessageSuccess channelId, message
        else
          loadMessage(message.parentId).then ->
            dispatchLoadMessageSuccess channelId, message


###*
 * An action creator to group load message action operations.
 * It wraps given message with realtimeActionCreators to transform realtime
 * events to flux actions.
 *
 * @param {string} channelId
 * @param {SocialMessage} message
 * @api private
###
dispatchLoadMessageSuccess = (channelId, message) ->

  channel = kd.singletons.socialapi.retrieveCachedItemById channelId

  realtimeActionCreators.bindMessageEvents message
  dispatch actionTypes.LOAD_MESSAGE_SUCCESS, { channelId, channel, message }


###*
 * An empty promise resolver. It's being used for default cases that returns
 * promise to keep API consistent.
###
emptyPromise = new Promise (resolve) -> resolve()


###*
 * Loads the message with given message id. It doesn't fetch if there is a
 * fetch going on with given messageId.
 *
 * @param {string} messageId
###
loadMessage = do (fetchingMap = {}) -> (messageId) ->

  return emptyPromise  unless messageId

  # if there is already a fetch going on for that message just return an empty
  # Promise.
  return emptyPromise  if fetchingMap[messageId]

  # mark this message id as being fetched.
  fetchingMap[messageId] = yes

  { socialapi } = kd.singletons
  { LOAD_MESSAGE_BEGIN
    LOAD_MESSAGE_FAIL } = actionTypes

  dispatch LOAD_MESSAGE_BEGIN, { messageId }

  socialapi.message.byId { id: messageId }, (err, message) ->
    if err
      dispatch LOAD_MESSAGE_FAIL, { err, messageId }
      return

    dispatchLoadMessageSuccess message.initialChannelId, message
    # unmark this message for being fetched.
    loadComments message.id
    fetchingMap[messageId] = no


###*
 * Action to load message with given slug.
 *
 * @param {string} slug
###
loadMessageBySlug = (slug) ->

  { socialapi } = kd.singletons
  { LOAD_MESSAGE_BY_SLUG_BEGIN
    LOAD_MESSAGE_BY_SLUG_FAIL
    LOAD_MESSAGE_SUCCESS } = actionTypes

  dispatch LOAD_MESSAGE_BY_SLUG_BEGIN, { slug }

  socialapi.message.bySlug { slug }, (err, message) ->
    if err
      dispatch LOAD_MESSAGE_BY_SLUG_FAIL, { err, slug }
      return

    dispatchLoadMessageSuccess message.initialChannelId, message
    loadComments message.id


###*
 * Action to create a message.
 *
 * @param {string} channelId
 * @param {string} body
 * @param {object=}
###
createMessage = (channelId, body, payload) ->

  payload = messageHelpers.sanitizePayload payload

  { socialapi } = kd.singletons
  { CREATE_MESSAGE_BEGIN
    CREATE_MESSAGE_FAIL
    CREATE_MESSAGE_SUCCESS } = actionTypes

  clientRequestId = generateFakeIdentifier Date.now()

  dispatch CREATE_MESSAGE_BEGIN, {
    channelId, clientRequestId, body
  }

  socialapi.message.post { channelId, clientRequestId, body }, (err, message) ->
    if err
      dispatch CREATE_MESSAGE_FAIL, {
        err, channelId, clientRequestId
      }
      return

    channel = socialapi.retrieveCachedItemById channelId

    realtimeActionCreators.bindMessageEvents message
    dispatch CREATE_MESSAGE_SUCCESS, {
      message, channelId, clientRequestId, channel
    }


###*
 * Remove a message.
 *
 * @param {string} messageId
###
removeMessage = (messageId) ->

  { socialapi } = kd.singletons
  { REMOVE_MESSAGE_BEGIN
    REMOVE_MESSAGE_FAIL
    REMOVE_MESSAGE_SUCCESS } = actionTypes

  dispatch REMOVE_MESSAGE_BEGIN, { messageId }

  socialapi.message.delete { id: messageId }, (err) ->
    if err
      dispatch REMOVE_MESSAGE_FAIL, { err, messageId }
      return

    dispatch REMOVE_MESSAGE_SUCCESS, { messageId }



###*
 * Like a message.
 *
 * @param {string} messageId
###
likeMessage = (messageId) ->

  { socialapi } = kd.singletons
  { LIKE_MESSAGE_BEGIN
    LIKE_MESSAGE_FAIL
    LIKE_MESSAGE_SUCCESS } = actionTypes

  userId = whoami()._id

  dispatch LIKE_MESSAGE_BEGIN, { messageId, userId }

  socialapi.message.like { id: messageId }, (err) ->
    if err
      dispatch LIKE_MESSAGE_FAIL, { err, messageId, userId }
      return

    socialapi.message.listLikers { id: messageId }, (err, likers) ->
      kd.singletons.reactor.batch ->
        likers.forEach (id) ->
          dispatch LIKE_MESSAGE_SUCCESS, { userId: id, messageId }


###*
 * Unlike a message.
 *
 * @param {string} messageId
###
unlikeMessage = (messageId) ->

  { socialapi } = kd.singletons
  { UNLIKE_MESSAGE_BEGIN
    UNLIKE_MESSAGE_FAIL
    UNLIKE_MESSAGE_SUCCESS } = actionTypes

  userId = whoami()._id

  dispatch UNLIKE_MESSAGE_BEGIN, { messageId, userId }

  socialapi.message.unlike { id: messageId }, (err, message) ->
    if err
      dispatch UNLIKE_MESSAGE_FAIL, { err, messageId }
      return

    dispatch UNLIKE_MESSAGE_SUCCESS, { messageId, userId }


###*
 * Edit message.
 *
 * @param {string} messageId
 * @param {string} body
 * @param {object=} payload
###
editMessage = (messageId, body, payload) ->

  payload = messageHelpers.sanitizePayload payload

  { socialapi } = kd.singletons
  { EDIT_MESSAGE_BEGIN
    EDIT_MESSAGE_SUCCESS
    EDIT_MESSAGE_FAIL } = actionTypes

  dispatch EDIT_MESSAGE_BEGIN, { messageId, body, payload }

  socialapi.message.edit {id: messageId, body, payload}, (err, message) ->
    if err
      dispatch EDIT_MESSAGE_FAIL, { err, messageId }
      return

    realtimeActionCreators.bindMessageEvents message
    dispatch EDIT_MESSAGE_SUCCESS, { message, messageId }


###*
 * Action to load comments with given options.
 *
 * @param {string} messageId
 * @param {string} from
 * @param {number} limit
###
loadComments = (messageId, options = {}) ->

  options.limit ?= 25
  { socialapi } = kd.singletons
  { LOAD_COMMENTS_BEGIN
    LOAD_COMMENTS_FAIL
    LOAD_COMMENTS_SUCCESS
    LOAD_COMMENT_SUCCESS } = actionTypes

  _options = _.assign {}, options, { messageId }

  dispatch LOAD_COMMENTS_BEGIN, _options

  socialapi.message.listReplies _options, (err, comments) ->
    if err
      dispatchData = _.assign {}, { err }, options
      dispatch LOAD_COMMENTS_FAIL, dispatchData
      return

    dispatch LOAD_COMMENTS_SUCCESS, { messageId }

    kd.singletons.reactor.batch ->
      comments.forEach (comment) ->
        realtimeActionCreators.bindMessageEvents comment
        dispatch LOAD_COMMENT_SUCCESS, { messageId, comment }


###*
 * Adds comment to given message.
 *
 * @param {string} messageId
 * @param {string} body
 * @param {object=} payload
###
createComment = (messageId, body, payload) ->

  payload = messageHelpers.sanitizePayload payload

  { socialapi } = kd.singletons
  { CREATE_COMMENT_BEGIN
    CREATE_COMMENT_FAIL
    CREATE_COMMENT_SUCCESS } = actionTypes

  clientRequestId = generateFakeIdentifier Date.now()

  dispatch CREATE_COMMENT_BEGIN, { messageId, clientRequestId, body }

  socialapi.message.reply { messageId, clientRequestId, body, payload }, (err, comment) ->
    if err
      dispatch CREATE_COMMENT_FAIL, { err, comment, clientRequestId }
      return

    addMessageReply = require 'activity/mixins/addmessagereply'
    message         = socialapi.retrieveCachedItemById messageId
    realtimeActionCreators.bindMessageEvents comment
    addMessageReply message, comment
    dispatch CREATE_COMMENT_SUCCESS, { messageId, comment, clientRequestId }


###*
 * Changes selected message id.
 *
 * @param {string} messageId
###
changeSelectedMessage = (messageId) ->

  dispatch actionTypes.SET_SELECTED_MESSAGE_THREAD, { messageId }


###*
 * Change selected message with given slug.
 *
 * @param {string} slug
###
changeSelectedMessageBySlug = (slug) ->

  { SET_SELECTED_MESSAGE_THREAD_FAIL,
    SET_SELECTED_MESSAGE_THREAD } = actionTypes

  kd.singletons.socialapi.message.bySlug { slug }, (err, message) ->
    if err
      dispatch SET_SELECTED_MESSAGE_THREAD_FAIL, { err, slug }
      return

    dispatch SET_SELECTED_MESSAGE_THREAD, { messageId: message.id }


module.exports = {
  loadMessages
  loadPublicChannelMessages
  loadMessageBySlug
  createMessage
  likeMessage
  unlikeMessage
  removeMessage
  editMessage
  loadComments
  createComment
  changeSelectedMessage
  changeSelectedMessageBySlug
}

