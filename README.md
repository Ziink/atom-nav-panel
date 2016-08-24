# Original package
This package is a fork from Ziink/atom-nav-panel

# Navigation Panel

Navigate using bookmarks and symbols. Whenever you open a file, it is scanned
for symbols and to dos, and a navigation panel is displayed to the right.
The panel is displayed only when there's something to show.
It can be turned on and off on demand.

![Scren Shot](https://raw.githubusercontent.com/0tho/atom-nav-panel-plus/master/screenshot/screenshot1.png)

Comes prepackaged with rules for various file types. They might be a little
flaky though. You can create your own project specific rules or
customize the rules within any given file. Your custom configuration can
add to the existing rules or replace them.

Bookmarks are saved across sessions.

**alt-click** on gutter (where the line numbers show) to toggle the bookmark
**right-click** on editor and select 'Toggle Nav Panel' to show/hide the panel.

In the navigation panel, click on the icon of an item to highlight it and
 the associated line of code. Click on the item to go to the associated
 line.


### Project rules
Create a file '.nav-marker-rules' in your project's root directory to define your own rules.

Each rule is on a single line. If a line does not match the format, it is ignored.

0. The line should begin with '#marker-rule:' (without quotes)
0. This is followed by at least one field from below. Different fields should be separated by **||** (two vertical bars)
0. The regular expression pattern if needed should be next. This is matched against each line.
0. Label for the item. Usually involves a captured group in the regular pattern and indicated with %n where n is an integer indicating the captured group. If this is absent, the entire match is used as the item label.
0. Name of the kind of match sought by the regular expression. E.g. Function or Variable or whatever makes most sense. If absent, any item found is grouped under 'Markers'
0. startOver: If this word (case matters) is a field, all previous rules are discarded
0. ext=fileExt1,fileExt2 : This is not needed if the rule applies to the file it is in.
0. disable=kind1,kind2 : Disables any rules of those kinds. E.g. 'Function' is a kind. These show up as main groups in the Nav Panel.

Examples

```
#marker-rule: /#[ \t]*urgent: (.*)/||Urgent||ext=.md
#marker-rule: /function (\w+)/||%1||Function
#marker-rule: /function (\w+)/i||%1||Function||startOver
#marker-rule: disable=Variable
```

### Rules within a source file
You can also intersperse rules within a file.
