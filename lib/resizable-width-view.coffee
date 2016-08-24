$ = require 'jquery'

module.exports =
class ResizableWidthView
  viewContainer: null
  mainView: null
  handle: null
  resizerPos: null


  constructor: (resizerPos = 'left')->
    @resizerPos = resizerPos

    fragment = """
    <div class="zi-width-resizer right"></div>
    <div class="zi-mainview"></div>
    """

    html = """
    <div class="zi-resizable">
    #{fragment}
    </div>
    """
    @viewContainer = $(html)
    @mainView = @viewContainer.find('.zi-mainview')
    @handle = @viewContainer.find('.zi-width-resizer')
    @handleEvents()


  handleEvents: ->
    @handle.on 'dblclick', =>
      @resizeToFitContent()

    @handle.on  'mousedown', (e) => @resizeStarted(e)


  resizeStarted: =>
    $(document).on('mousemove', @resizeView)
    $(document).on('mouseup', @resizeStopped)


  resizeStopped: =>
    $(document).off('mousemove', @resizeView)
    $(document).off('mouseup', @resizeStopped)


  resizeView: ({pageX, which}) =>
    return @resizeStopped() unless which is 1

    if @resizerPos == 'left'
      deltaX = @handle.offset().left - pageX
      width = @viewContainer.width() + deltaX
    else
      deltaX =  pageX - @handle.offset().left
      width = @viewContainer.width() + deltaX
    @viewContainer.width(width)

  resizeToFitContent: ->
    @viewContainer.width(@mainView.width() + 20)

  moveHandleLeft: ->
    @handle.addClass('left')
    @handle.removeClass('right')
    @resizerPos = 'left'

  moveHandleRight: ->
    @handle.addClass('right')
    @handle.removeClass('left')
    @resizerPos = 'right'
