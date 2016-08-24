$ = require 'jquery'
NavView = require './nav-view'
Parser = require './nav-parser'

path = require 'path'

{CompositeDisposable} = require 'atom'


module.exports =
  navView: null
  parser: null
  subscriptions: null

  config:
    collapsedGroups:
      title: 'Groups that are initially collapsed'
      description: 'List groups separated by comma (e.g. Variable) '
      type: 'string'
      default: 'Variable'
    ignoredGroups:
      title: 'Groups that are ignored'
      description: 'These groups will not be displayed at all'
      type: 'string'
      default: ''
    topGroups:
      title: 'Groups at top'
      description: 'Groups that are displayed at the top, irrespective of sorting'
      type: 'string'
      default: 'Bookmarks, Todo'
    noDups:
      title: 'No Duplicates'
      type: 'boolean'
      default: true
    leftPanel:
      title: 'Should panel be on the left'
      type: 'boolean'
      default: false


  activate: (state) ->
    @enabled = !(state.enabled == false)
    @subscriptions = new CompositeDisposable

    settings = atom.config.getAll('nav-panel-plus')[0].value
    settings.leftPanel = if settings.leftPanel then 'left' else 'right'

    @parser = new Parser()
    @navView = new NavView(state, settings, @parser)

    @subscriptions.add atom.config.onDidChange 'nav-panel-plus', (event) =>
      settings = event.newValue
      for key, value in settings
        if key.indexOf('Groups') > 0
          settings[key] = value.split(',')
      settings.leftPanel = if settings.leftPanel then 'left' else 'right'
      @navView.changeSettings(settings)

    @subscriptions.add atom.commands.add 'atom-workspace'
      , 'nav-panel-plus:toggle': => @toggle()

    @subscriptions.add atom.commands.add 'atom-workspace'
      , 'nav-panel-plus:changeSide': => @changePanelSide()

    @subscriptions.add atom.workspace.onDidStopChangingActivePaneItem (paneItem)=>
      editor = atom.workspace.getActiveTextEditor()
      return @navView.hide() unless editor
      return if editor != paneItem
      editorFile = editor.getPath() # undefined for new file
      @navView.setFile(editorFile)
      # Panel also needs to be updated when text saved
      return unless editor and editor.onDidSave
      if !editor.ziOnEditorSave
        editor.ziOnEditorSave = editor.onDidSave (event) =>
          return unless @enabled
          # With autosave, this gets called before onClick.
          # We want click to be handled first
          # setImmediate didn't work.
          setTimeout =>
            editorFile = editor.getPath()
            @navView.updateFile(editorFile) if editorFile
          , 200
        @subscriptions.add editor.ziOnEditorSave

        @subscriptions.add editor.onDidDestroy =>
          @navView.closeFile(editorFile)

    @subscriptions.add atom.workspace.onWillDestroyPaneItem (event)=>
      if event.item.ziOnEditorSave
        @navView.saveFileState(event.item.getPath())


  deactivate: ->
    @navView.destroy()
    @parser.destroy()
    @subscriptions.dispose()
    @navView = null


  serialize: ->
    enabled: @enabled
    fileStates: @navView.getState()


  toggle: ->
    @enabled = not @enabled
    @navView.enable(@enabled)

  changePanelSide: ->
    @navView.movePanel()
