fs = require 'fs'
path = require 'path'
{langdef, langmap} = require './ctags'

# RegExp to capture any arguments within () or within []
argsRe = {
  '()': /(\([^)]+\))/
  '[]': /(\[[^\]]+\])/
}
indentSpaceRe = /^(?: |\t)*/
positionRe = []
for i in [0..9]
  positionRe[i] = new RegExp('%' + i, 'g')


module.exports =
class NavParser
  pathObserver: null
  projectRules : {}


  constructor: ->
    @getProjectRules atom.project.getPaths()
    pathObserver = atom.project.onDidChangePaths (paths)=>
      @getProjectRules paths


  getProjectRules: (paths)->
    # First remove any project that's been closed
    for projectPath of @projectRules
      if paths.indexOf(projectPath) == -1
        delete @projectRules[projectPath]
    # Now any new project opened.
    for projectPath in paths
      ruleFile = projectPath + path.sep + '.nav-marker-rules'
      if !@projectRules[projectPath]
        do (projectPath)=>
          fs.readFile ruleFile, (err,data)=>
            return unless data
            rulesText = data.toString().split("\n")
            for line in rulesText
              rule = @parseRule(line)
              if rule
                @projectRules[projectPath] ||= []
                @projectRules[projectPath].push rule


  parse: ->
    # parse active editor's text
    items = []
    editor = atom.workspace.getActiveTextEditor()
    return items unless editor
    editorFile = editor.getPath()
    return unless editorFile  # happens with new file

    activeRules = langdef.All || []
    markerIndents = []    # indent chars to track parent/children

    updateRules = (newRule)->
      if newRule.ext
        fileMatches = false
        for ext in newRule.ext
          if editorFile.lastIndexOf(ext) + ext.length == editorFile.length
            fileMatches = true
            break
        return unless fileMatches
      if newRule.startOver
        activeRules = []
      if newRule.disableGroups
        for disableGroup in newRule.disableGroups
          for rule, i in activeRules
            if rule.kind == disableGroup
              activeRules.splice(i, 1)
      if newRule.re
        activeRules.push newRule

    prevIndent = 0
    for ext in Object.keys(langmap)
      if editorFile.lastIndexOf(ext) + ext.length == editorFile.length
        activeRules = activeRules.concat(langmap[ext])
        break

    # incorporate project rules
    for projectPath of @projectRules
      if editorFile.indexOf(projectPath) == 0
        projectRules = @projectRules[projectPath]
        for rule in projectRules
          updateRules(rule)

    for row in [0..editor.getLineCount() ]
      lineText = editor.lineTextForBufferRow(row)
      lineText = lineText.trim() if lineText
      continue if !lineText
      if lineText.indexOf('#' + 'marker-rule:') >= 0
        newRule = @parseRule(lineText)
        if newRule
          updateRules(newRule)
          continue

      # Track indent level
      indent = lineText.match(indentSpaceRe)[0].length
      while indent < prevIndent
        prevIndent = markerIndents.pop()

      for rule in activeRules
        match = lineText.match(rule.re)
        if match
          parentIndent = -1
          markerIndents.push(indent) if indent > prevIndent
          if markerIndents.length > 1
            parentIndent = markerIndents[markerIndents.length-2]
          items.push @makeItem(rule, match, lineText, row, indent, parentIndent)
    return items


  makeItem: (rule, match, text, row, indent, parentIndent) ->
    label = rule.id || ''
    tooltip = rule.tooltip || ''
    icon = rule.icon #|| 'primitive-dot'
    if label or tooltip
      for str, i in match
        if label
          label = label.replace(positionRe[i], match[i])
        if tooltip
          tooltip = tooltip.replace(positionRe[i], match[i])
    if ! label
      label = match[1] || match[0]

    kind = rule.kind || 'Markers'

    if rule.args
      argsMatch = argsRe[rule.args].exec(text)
      tooltip += argsMatch[1] if argsMatch

    item = {label: label, icon: icon, kind: kind, row: row
      , tooltip: tooltip, indent: indent, parentIndent: parentIndent}


  # parseRule : to decipher rules in .nav-marker-rules file or within source
  parseRule: (line) ->
    # Should be: '#marker-rule' followed by colon, then by regular expression
    # followed by optional fields separated by ||
    # optional fields are
    # identifier (label) which must have one of %1 through %9 if present
    # kind : e.g. Function. Default is 'Markers'
    # startOver : The literal text 'startOver'. Discards any previous rules
    # disable=kind1,kind2 : Disable specified kinds
    # ext=.coffee,.js
    return unless line
    ruleStr = line.split('#' + 'marker-rule:')[1].trim()
    return unless ruleStr
    parts = ruleStr.split('||')
    reFields = parts[0].match(/[ \t]*\/(.+)\/(.*)/)
    if !reFields && ruleStr.search(/(^|\|\|)(startOver|disable=)/) == -1
      console.log 'Navigator Panel: No regular expression found in :', line
      return
    rule = {}
    if reFields
      reStr = reFields[1] #.replace(/\\/g, '\\\\')
      flag = 'i' if reFields[2]
      rule = {re: new RegExp(reStr, flag)}
      parts.shift()

    for part in parts
      if part.indexOf('%')  != -1
        rule.id = part
      else if part.indexOf('startOver') == 0
        rule.startOver = true
      else if part.indexOf('disable=') == 0
        rule.disableGroups = part.substr('disable='.length).split(',')
      else if part.indexOf('ext=') == 0
        rule.ext = part.substr('ext='.length).split(',')
      else
        rule.kind = part
    return rule


  destroy: ->
    @pathObserver.dispose()
