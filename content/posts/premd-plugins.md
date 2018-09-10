---
title: "Premarkdown Plugins"
date: 2018-09-10T14:25:40+02:00
tags: [writing, python, programming]
---

I'm working on a preprocessor for Markdown documents. I write all my books in Markdown, so this is something I have wanted to do for a while, to scratch a few itches I have.

I write my books in Markdown and then I process them using Pandoc. If you are not familiar with that setup, then I have written a short book on the topic: [*The Beginner's Guide to Markdown and Pandoc*](https://amzn.to/2MYEMUC).

For that book, because it is very short, I just have a single Markdown document containing the entire book, but usually, I have one file per chapter. Pandoc doesn't handle that, but you can cat the files before you convert the Markdown source to PDF or ePUB documents. That works well enough, but you need to keep track of the chapter order and such, of course.

I handle that with Makefiles, but any script would work just as well. There is just one thing I don't particularly like with this. It is difficult to move sections around within the chapters—you have to cut and paste to do this. Plus, if you want to have some markup inside the documents, as comments, then Pandoc cannot handle that.

I write using iA Writer, and there you can include other files by just writing slash and then the filename. Like this:

```markdown
# The main title

/chapter1.md
/chapter2.md
/chapter3.md
```

That will include the three chapter-files into the main document. That doesn't solve particularly much, but you can then include sections from the chapter files and such. This makes it easy to move sections and chapters around—similar to how Ulysses deals with sections.

I stopped using Ulysses when the changed to a subscription plan, but I was annoyed with having to export Markdown documents from it every time I needed to compile a document. I miss moving sections around, but not exporting. I don't have to export anything when writing in iA Writer, but Pandoc doesn't include files the same way as iA Writer does.

So, I wanted to have a preprocessing step that flattens a hierarchy of included files before compiling a document. I don't want to keep track of that in a Makefile, but just include sections from chapters and include chapters from a main file. I wrote a script, `premd` to handle this.

If I preprocess files to flatten the hierarchy, then I can also add tags for comments. So I decided to use `%%` to start comments, and my preprocessor does not include lines that start with that in the output.

I want to do more with comments than ignore them, though. I want to be able to add writing goals and FIXME statements so I can extract meta-information while I process the document.

So, I decided to use a plugin mechanism to add two ways of extracting meta-information. I have two types right now; I call them them "tag" plugins and "observer" plugins

```python
class TagPlugin(abc.ABC):
	@abc.abstractmethod
	def handle_tag(self, file, lineno, content):
		pass

class ObserverPlugin(abc.ABC):
    @abc.abstractmethod
    def observe_line(self, filename, lineno, line):
        pass
```

and those plugins I want to display summaries of the document after I have processed it (or if I just want to extract summaries) I call "summary" plugins

```python
class SummaryPlugin(abc.ABC):
    @abc.abstractmethod
    def summarize(self, outfile):
        pass
```

You can combine these anyway you want, and I currently have two concrete plugins: "WC" for word counts and "FIXME" for extracting "fixme" information.

```python
class WC(plugin.ObserverPlugin, plugin.SummaryPlugin):
	…
	
class FIXME(plugin.TagPlugin, plugin.SummaryPlugin):
	…
```

They are both summary plugins because they should output summary information, but the word count plugin observes the entire document while the fixme plugin only observes "tags" and summarises data it gets from these.

The observer plugins are fed all lines in the document, after it is flattened, while the tag plugins sees comment lines that starts with a tag it tells the preprocessor it wants to see.

The "FIXME" plugin sees these tags:

```python
class FIXME(plugin.TagPlugin, plugin.SummaryPlugin):
    """FIXMEs in document"""
    supported_tags = [
        "FIXME", "Fixme", "fixme",
        "TODO", "Todo", "todo"
    ]
	…
```

When `permed` is told there is a tag plugin, it gets the class-variable `supported_tags` and feed these tags to the plugin. The tags have the form `%% tag: …`, and the tag plugin is called with the text that follows the `tag:`.

You can inform the `premd` too that you have a plugin for it using entry points. I have these built into the tool:

```python
    entry_points={
		    …,
        'premd.plugins': [
            'fixme = premd.plugins.fixme:FIXME',
            'wc = premd.plugins.wc:WC'
        ]
    },
```

The tool figures out what kind of a plugin it is from its super-classes. I can also get these from a more protocol-oriented design using the `__subclasshook__` mechanism, but I haven't decided on whether that is a good idea or not. 

This works okay now. I can extract `FIXME` comments and I can extract word-counts (per chapter, section, etc.). But I am never satisfied and I want more!

There are two things I want to add to `premd` as soon as I have time: I want to handle tags in a smarter way, and I want to allow plugins to add to the document and not just read from it.

## Smarter tag handling

The tag plugin mechanism is okay I guess. I can add writing goals to a section or chapter using a `%% goals:` tag, I guess, and make the word count plugin read those. It will work, but I think I can do better than that. If I use the current design, I can only call tag handlers with a string, but since I can inspect classes and methods, I think I should be able to use tags to call specific methods, for example write

```markdown
# A section
%% wordcount.set_goals: goal: 5000
```

or 

```markdown
# A section
%% wordcount.set_goals: at_least: 4500 at_most: 5500
```

and make those tags call the word counter plugin using keyword arguments

```python
plugin.get_goals(goal=5000)
```

or

```python
plugin.set_goals(at_least=4500, at_most=5500)
```

and automatically convert the arguments if the method has type annotations.

This is a lot more flexible, and I don't think it will be terribly hard to implement. I haven't thought too deeply about what the design should be to make this work, but designing the interface is probably a lot harder than actually implementing it.

## Adding to the output stream of the flattening

To have an actual preprocessor, I want to allow plugins to add to the document as well as inspect it. I am not sure what the right interface should be here, though.

It is probably easiest to use tags for this. I could add the output stream to the function call that handles tags, for example, or check if it is a generator and then get lines it output using `yield from`.

If a plugin is a co-routine, I would also be able to pass information back to the plugin, but that might just as easily be handled by tags. I don't know yet.

I think my main concerns with designing this would be how to handle the setup of plugins and how to provide multi-line input to plugins.

If there is any kind of complex setup for a plugin, I want to be able to handle that in a configuration file or in the main document itself. So I need some sort of block-tag to handle that. A block-tag will also allow me to give a plugin larger chunks of input to process.

R Markdown handles blocks with headers in curly braces, and if I add a similar design I could write something like this:

```markdown
```{pluginname, keyword=foo, arguments=bar}
input to plugin
```

The plugin can then do whatever it wants with the input, for example setup the state of the plugin or use it to produce output.

With R Markdown, the `knitr` tool will let you execute and output R code, but with a general design I could imagine plugins that execute arbitrary code, or for example compile code into executables (for complied languages like `C` or `go`) and get the output for this. If it doesn't produce output, perhaps it can test code instead. With the right design for this, I can leave it up to the plugins.

I am not sure if this will suffice for conditional inclusions of part of a document. I haven't thought too much about this, since I haven't used conditional sections in a while, but it might require a different kind of plugin or a chance to the `premd` tool.

Anyway, I would love to hear your ideas, and if you want to take the tool for a test drive you can get it on [GitHub](https://github.com/mailund/premarkdown).