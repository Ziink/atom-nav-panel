$ = require 'jquery'

module.exports =
class ResizableWidthView
  viewContainer: null
  mainView: null
  handle: null
  resizerPos: null


  constructor: (resizerPos = 'left')->
    @resizerPos = resizerPos
    if resizerPos == 'left'
      fragment = """
      <div class="zi-width-resizer"></div>
      <div class="zi-mainview"></div>
      """
    else
      fragment = """
      <div class="zi-mainview"></div>
      <div class="zi-width-resizer"></div>
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
      deltaX = @viewContainer.offset().left - pageX
      width = @viewContainer.width() + deltaX
    else
      width = pageX - @viewContainer.offset().left
    @viewContainer.width(width)


  resizeToFitContent: ->
    @viewContainer.width(@mainView.width() + 20)
