# Convert a .ctags file to a coffeescript so we don't have to process that each time.
fs = require 'fs'

langdef = {}  # language: [{regex}]
langmap = {}  # file ext -> langdef

reRegex = /^--regex-(\w+)=(.*)/
reLangmap = /^--langmap=(\w+):(.*)/
reRule = ///
  (\/.*\/)    # Regex. This is greedy so other fields will have to limit it
  ([^\/]+)\/  # identifier
  ([^\/]+)\/  # Type - kind
  ([a-z,]*$)  # Usually blank. For regex flags
  ///

addDef = (lang, rule)->
  langdef[lang] ||= []
  match = rule.match(reRule)
  kind = match[3]
  if kind.indexOf(',') > 0
    kinds = kind.split(',')
    kind = kinds[kinds.length-1]
    kind = kind.charAt(0).toUpperCase() + kind.slice(1)
  ruleObj = {re: match[1], id: match[2], kind: kind }
  ruleObj.flags = match[4] if match[4]
  langdef[lang].push ruleObj


addMap = (lang, ext)->
  langdef[lang] ||= []
  ext = ext.replace('+', '')
  langmap[ext] = lang

fs.readFile '.ctags', (err, data) =>
  console.error  err if err
  return unless data
  lines = data.toString().split("\n")
  for line in lines
    match = line.match(reRegex)
    if match
      addDef(match[1], match[2])
    else
      match = line.match(reLangmap)
      addMap(match[1], match[2]) if match

  outStr = "# Created by ctags2coffee.coffee by processing .ctags\n"
  outStr += "langdef = \n"
  for key in Object.keys(langdef)
    outStr += "  #{key}: [\n"
    for ruleObj in langdef[key]
      re = ruleObj.re + (ruleObj.flags || '')
      outStr += "    {re: #{re}, id: '#{ruleObj.id.replace(/\\/g, '%')}', kind: '#{ruleObj.kind}'"
      outStr += "}\n"
    outStr += "  ]\n"

  outStr += 'langmap = \n'
  for key in Object.keys(langmap)
    outStr += "  '#{key}': langdef.#{langmap[key]}\n"

  outStr += "module.exports = {langdef: langdef, langmap: langmap}\n"
  fs.writeFile('ctags.coffee', outStr, -> console.log 'done.')
