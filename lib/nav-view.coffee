$ = require 'jquery'
ResizableWidthView = require './resizable-width-view'

module.exports =
class NavView extends ResizableWidthView
  panel: null
  filePanel: null  # main elem for current file
  bottomGroups: []
  enabled: true
  settings: {}
  parser: null  # parser supplied by client code
  state: {}
  view: null

  nextId: 1   # To mark the dom item


  constructor: (state, settings, parser)->
    super()
    @enabled = !(state.enabled == false)
    @state = state.fileStates || {}
    @changeSettings(settings)
    @parser = parser

    # Add to the panel
    @panel = atom.workspace.addRightPanel(
      item: @viewContainer
      visible: false
      priority: 300
    )
    @viewContainer.addClass('zi-marker-panel')
    html = """
    <div class='zi-header'>
      <div class='icon icon-arrow-down' title='Toggle Sorting'></div>
      <h2>Nav Panel</h2>
    </div>
    <div class='zi-view'>
    </div>
    """
    $(html).appendTo(@mainView)
    @view = @mainView.find('.zi-view')
    @view.on 'click', '.list-item', (event)=>
      elem = event.currentTarget
      if elem.markerId
        if $(event.target).hasClass('icon')
          @toggleHighlight(elem)
        else
          @gotoMarker(elem.markerId)
      else if $(elem).is('.zi-marker-group-label')
        $(elem).parent().toggleClass('collapsed')
    @mainView.on 'click', '.icon-arrow-down', =>
      editor = atom.workspace.getActiveTextEditor()
      return unless editor
      file = editor.getPath()
      @state[file] ||= {}
      if @state[file].sort == undefined
        @state[file].sort = @settings.sort
      else
        @state[file].sort = !@state[file].sort
      @updateFile(file)



  destroy: ->
    @view.children().each =>
      @destroyPanel($(this))
    @panel.destroy()


  changeSettings: (settings)->
    @settings = settings


  getFilePanel: (file)->
    filePanel = null
    @view.children().each ->
      if $(this).data('file') == file
        filePanel = $(this)
        return false
      return true
    return filePanel


  getFileEditor: (file)->
    editors = atom.workspace.getTextEditors()
    for editor in editors
      if editor.getPath() == file
        return editor
    return null


  setFile: (file)->
    return unless file
    newElem = @getFilePanel(file)
    #todo: If we have multiple panes this might give some odd results
    editor = @getFileEditor(file)
    editorView = atom.views.getView(editor)
    gutter = $('.gutter-container', editorView.shadowRoot)
    if !gutter.data('zNavPanelMouse')
      gutter.data('zNavPanelMouse', 'done')
      do (editor)=>
        gutter.on 'mousedown', '.line-number', (event) =>
          return unless @enabled
          if event.which != 1 || event.altKey == false ||
              event.ctrlKey == true || event.shiftKey == true
            # return if not alt-click
            return
          #todo: determine why stopPropagation and preventDefault don't work
          # for the line still gets selected
          event.stopPropagation()
          event.preventDefault()
          row = +($(event.target).attr('data-buffer-row'))
          @toggleBookmark(row, editor)
    if newElem
      # Had previously been set up
      return @setVisibility() if newElem == @filePanel
      return @switchPanel(newElem)
    @populatePanel(editor)


  updateFile: (file)->
    editor = @getFileEditor(file)
    oldPanel = @getFilePanel(file)
    if oldPanel   # oldPanel is null when newly created file is saved
      prevState = @getPanelState(oldPanel)
      @state[file] = prevState
      @destroyPanel(oldPanel)
    @populatePanel(editor)
    @setVisibility()


  getPanelState: (panel)->
    return unless panel
    state = {collapsedGroups: [], bookmarks: [], highlights: {}}
    file = panel.data('file')
    editor = @getFileEditor(file)
    return unless editor
    groups = panel.find(".zi-marker-group")
    groups.each ->
      group = $(this)
      groupLabel = $(this).find('.zi-marker-group-label').text().trim()
      if $(this).hasClass('collapsed')
        state.collapsedGroups.push groupLabel
      if groupLabel == 'Bookmarks' && editor
        group.find('li.list-item').each ->
          row = editor.getMarker(this.markerId).getStartBufferPosition().row
          state.bookmarks.push row
      # Save items that have highlights
      group.find('li.zi-highlight').each ->
        state.highlights[groupLabel] ||= []
        row = editor.getMarker(this.markerId).getStartBufferPosition().row
        state.highlights[groupLabel].push row
    if @state[file] && @state[file].sort != undefined
      state.sort = @state[file].sort
    return state



  setPanelState: (panel, state)->
    return unless panel && state
    editor = @getFileEditor(panel.data('file'))
    return unless editor

    prevFilePanel = null
    if @filePanel != panel
      prevFilePanel = @filePanel
      @filePanel = panel

    # First deal with bookmarks
    if state.bookmarks.length
      bookmarksGroup = @addGroup('Bookmarks')
      for bookmarkRow in state.bookmarks
        @toggleBookmark(bookmarkRow, editor, true)
    # Now hightlights
    for groupLabel in Object.keys(state.highlights)
      for highlightRow in state.highlights[groupLabel]
          @toggleHighlight(@getItemByOrigRow(highlightRow, groupLabel), editor)
    # Now collapsed Groups
    groups = panel.find(".zi-marker-group")
    groups.each ->
      group = $(this)
      groupLabel = $(this).find('.zi-marker-group-label').text().trim()
      if state.collapsedGroups.indexOf(groupLabel) >= 0
        group.addClass('collapsed')
      else
        group.removeClass('collapsed')

    @filePanel = prevFilePanel if prevFilePanel


  getState: ->
    # state for each panel by file
    @view.children().each =>
      panel = $(this)
      file = panel.data('file')
      panelState = @getPanelState(panel)
      @state[file] = panelState
    return @state


  saveFileState: (file)->
    panel = @getFilePanel(file)
    state = @getPanelState(panel)
    @state[file] = state if state


  closeFile: (file)->
    panel = @getFilePanel(file)
    return unless panel
    panelState = @getPanelState(panel)
    @state[file] = panelState if panelState
    @destroyPanel(panel) if panel


  switchPanel: (panel)->
    @filePanel.hide()
    @filePanel = panel
    @setVisibility()


  arrangeItems: (items, file)->
    arrangedItems = []
    if @settings.noDups
      prevItems = []
      for item in items
        dupKey = item.kind + '||' + item.label
        continue if prevItems.indexOf(dupKey) >= 0
        prevItems.push(dupKey)
        arrangedItems.push item
    else
      arrangedItems = items.slice(0)
    if @state[file] && @state[file].sort != undefined
      sort = @state[file].sort
    else
      sort = @settings.sort
    if sort
      arrangedItems.sort (a,b)->
        key1 = (a.kind + '||' + a.label).toLowerCase()
        key2 = (b.kind + '||' + b.label).toLowerCase()
        return 0 if key1 == key2
        return 1 if key1 > key2
        return -1
    return arrangedItems


  populatePanel: (editor)->
    # new
    editor = atom.workspace.getActiveTextEditor() unless editor
    file = editor.getPath()
    @filePanel = $("<ul class='list-tree has-collapsable-children'>").appendTo(@view)
    @filePanel.data('file', file)
    items = @parser.parse()
    if items
      items = @arrangeItems(items, file)
      for item in items
        {id, elem} = @addPanelItem(item)
        marker = editor.markBufferPosition([item.row, 0])
        marker.zItemId = id
        elem[0].markerId = marker.id
    # @view.children().hide()
    @setVisibility()
    @setPanelState(@filePanel, @state[file])


  gotoMarker: (markerId)->
    editor = atom.workspace.getActiveTextEditor()
    marker = editor.getMarker(markerId)
    return unless marker
    row = marker.getStartBufferPosition()
    editor.unfoldBufferRow(row)
    editor.setCursorBufferPosition(row)
    editor.scrollToCursorPosition()


  addGroup: (label)->
    # pos : presently should be 1 for top or undefined or jquery obj to insert after
    # returns element that new items can be appended to
    group = @filePanel.find(".zi-marker-group-label:contains(#{label})").siblings('ul.list-tree')
    return group if group.length

    if @settings.collapsedGroups.indexOf(label) >= 0
      collapsed = 'collapsed'
    else
      collapsed = ''

    html = """
      <li class='list-nested-item zi-marker-group #{collapsed}'>
        <div class='list-item zi-marker-group-label'>
          <span>#{label}</span>
        </div>
        <ul class='list-tree'>
        </ul>
      </li>
    """
    if @settings.topGroups.indexOf(label) >= 0
      elem = $(html).prependTo(@filePanel)
    else
      elem = $(html).appendTo(@filePanel)
    return elem.find('ul.list-tree')


  addPanelItem: (groupLabel, label, data)->
    # groupLabel could be an object & only arg
    # data -> {icon, tooltip, marker, decorator}
    # return id, data attached to object
    if typeof groupLabel != 'string'
      data = groupLabel
      groupLabel = data.kind
      label = data.label
    else
      data ||= {}

    group = @addGroup(groupLabel)
    if data.icon
      labelClass = "class='icon icon-#{data.icon}'"
    else
      labelClass = "class='icon icon-primitive-dot'"
    # Interim : Fix with a better approach
    tooltip = data.tooltip
    if !tooltip && label.length > 28
      tooltip = label.replace(/'/g, '&#39;')
    html = """
    <li id='zi-item-#{@nextId}' class='list-item' title='#{tooltip || ''}'>
      <span #{labelClass}></span>
      <span class='zi-marker-label'>#{label}</span>
    </li>
    """
    elem = $(html).appendTo(group)
    elem[0].origRow = data.row if data.row
    return {id: @nextId++, elem: elem}


  toggleHighlight: (element, editor)->
    element = element[0] if element.jquery
    return unless element
    editor = atom.workspace.getActiveTextEditor() unless editor
    if element.decoration
      element.decoration.destroy()
      $(element).removeClass('zi-highlight')
      return element.decoration = null
    else
      $(element).addClass('zi-highlight')
      marker = editor.getMarker(element.markerId)
      decoration = editor.decorateMarker(marker, {type: 'line-number', class: 'zi-highlight'})
      decoration.zNavPanelItem = true
      return element.decoration = decoration


  toggleBookmark: (lineNum, editor, skipHighlight) ->
    editor = atom.workspace.getActiveTextEditor() unless editor
    lineMarkers = editor.findMarkers({startBufferRow: lineNum, endBufferRow: lineNum})
    for lineMarker in lineMarkers
      continue unless lineMarker.zItemId
      if lineMarker.zNavPanelBookmark
        return @removeItem(lineMarker.zItemId, editor)
      decorations = editor.decorationsForMarkerId(lineMarker.id)
      if decorations
        for decoration in decorations
          if decoration.zNavPanelItem
            return @toggleHighlight(@getItemById(lineMarker.zItemId))

    # No existing bookmark so create one
    lineText = editor.lineTextForBufferRow(lineNum)
    lineText = lineText.trim() || '___ blank line ___'
    atomMarker = editor.markBufferPosition([lineNum, 0])
    {id, elem} = @addPanelItem('Bookmarks', lineText, {marker: atomMarker})
    atomMarker.zItemId = id
    atomMarker.zNavPanelBookmark = true
    elem[0].markerId = atomMarker.id
    elem[0].origRow = lineNum
    if !skipHighlight
      decoration = @toggleHighlight(elem[0], editor)
    @setVisibility()


  removeItem: (id, editor)->
    # Also remove group if last item
    item = $('#zi-item-' + id)
    return unless item.length

    editor = atom.workspace.getActiveTextEditor() unless editor
    item[0].decoration.destroy() if item[0].decoration
    if item[0].markerId
      marker = editor.getMarker(item[0].markerId)
      marker.destroy()
    if item.siblings().length
      item.remove()
    else
      item.parents('li.list-nested-item').first().remove()
    @setVisibility()


  getItemById: (id)->
    return $('#zi-item-' + id)


  getItemByOrigRow: (row, group)->
    elem = $()
    if group
      root = @filePanel.find(".zi-marker-group-label:contains(#{group})").siblings('ul.list-tree')
    else
      root = @filePanel
    root.find('li.list-item').each ->
      if this.origRow ==  row
        elem = $(this)
        return false
      return true
    return elem


  setVisibility: ->
    if @enabled && @filePanel?.find('li.list-item').length > 0
      @view.children().hide()
      @filePanel.show()
      @panel.show()
      return true
    else
      @panel.hide()
      return false


  hide: ->
    @panel.hide()


  enable: (enable)->
    @enabled = enable
    @setVisibility()


  destroyPanel: (filePanel)->
    editor = @getFileEditor(filePanel.data('file'))
    $(filePanel).find('li.list-item').each ->
      this.decorator.destroy() if this.decorator
      editor.getMarker(this.markerId)?.destroy() if editor
    filePanel.remove()
