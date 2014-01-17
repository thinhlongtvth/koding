class ActivityAppView extends KDScrollView


  headerHeight = 0


  constructor:(options = {}, data)->

    options.cssClass   = "content-page activity"
    options.domId      = "content-page-activity"

    super options, data

    # FIXME: disable live updates - SY
    @appStorage = KD.getSingleton("appStorageController").storage 'Activity', '1.0.1'
    @appStorage.setValue 'liveUpdates', off


  viewAppended:->

    {entryPoint}      = KD.config
    windowController  = KD.singleton 'windowController'

    @feedWrapper      = new ActivityListContainer
    @inputWidget      = new ActivityInputWidget

    @referalBox       = new ReferalBox
    @topicsBox        = new ActiveTopics
    @usersBox         = new ActiveUsers
    @tickerBox        = new ActivityTicker

    @mainBlock        = new KDCustomHTMLView tagName : "main" #"activity-left-block"
    @sideBlock        = new KDCustomHTMLView tagName : "aside"   #"activity-right-block"

    @groupCoverView   = new FeedCoverPhotoView

    @mainController   = KD.getSingleton("mainController")
    @mainController.on "AccountChanged", @bound "decorate"
    @mainController.on "JoinedGroup", => @inputWidget.show()

    @feedWrapper.ready =>
      @activityHeader  = @feedWrapper.controller.activityHeader
      {@filterWarning} = @feedWrapper
      {feedFilterNav}  = @activityHeader
      feedFilterNav.unsetClass 'multiple-choice on-off'

    @tickerBox.once 'viewAppended', =>
      topOffset = @tickerBox.$().position().top
      windowController.on 'ScrollHappened', =>
        if document.body.scrollTop > topOffset
        then @tickerBox.setClass 'fixed'
        else @tickerBox.unsetClass 'fixed'

    @decorate()

    @setLazyLoader 200

    @addSubView @mainBlock
    @addSubView @sideBlock

    @mainBlock.addSubView @groupCoverView
    @mainBlock.addSubView @inputWidget
    @mainBlock.addSubView @feedWrapper

    @sideBlock.addSubView @referalBox  if KD.isLoggedIn()
    @sideBlock.addSubView @topicsBox
    @sideBlock.addSubView @usersBox
    @sideBlock.addSubView @tickerBox

  decorate:->
    @unsetClass "guest"
    {entryPoint, roles} = KD.config
    @setClass "guest" unless "member" in roles
    # if KD.isLoggedIn()
    @setClass 'loggedin'
    if entryPoint?.type is 'group' and 'member' not in roles
    then @inputWidget.hide()
    else @inputWidget.show()
    # else
    #   @unsetClass 'loggedin'
    #   @inputWidget.hide()
    @_windowDidResize()

  setTopicTag: (slug) ->
    return  if not slug or slug is ""
    KD.remote.api.JTag.one {slug}, null, (err, tag) =>
      @inputWidget.input.setDefaultTokens tags: [tag]

  unsetTopicTag: ->
    @inputWidget.input.setDefaultTokens tags: []


class ActivityListContainer extends JView

  constructor:(options = {}, data)->
    options.cssClass = "activity-content feeder-tabs"

    super options, data

    @controller = new ActivityListController
      delegate          : @
      itemClass         : ActivityListItemView
      showHeader        : yes
      # wrapper           : no
      # scrollView        : no

    @listWrapper = @controller.getView()
    @filterWarning = new FilterWarning

    @controller.ready => @emit "ready"

  setSize:(newHeight)->
    # @controller.scrollView.setHeight newHeight - 28 # HEIGHT OF THE LIST HEADER

  pistachio:->
    """
      {{> @filterWarning}}
      {{> @listWrapper}}
    """

class FilterWarning extends JView

  constructor:->
    super cssClass : 'filter-warning hidden'

    @warning   = new KDCustomHTMLView
    @goBack    = new KDButtonView
      cssClass : 'goback-button'
      # todo - add group context here!
      callback : => KD.singletons.router.handleRoute '/Activity'

  pistachio:->
    """
    {{> @warning}}
    {{> @goBack}}
    """

  showWarning:({text, type})->
    partialText = switch type
      when "search" then "Results for <strong>\"#{text}\"</strong>"
      else "You are now looking at activities tagged with <strong>##{text}</strong>"

    @warning.updatePartial "#{partialText}"

    @show()
