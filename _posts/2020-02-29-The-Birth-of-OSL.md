---
layout: post
title: "The (Re)Birth of OSL; Nothing stays dead forever"
date: 2020-02-29 16:10:00 +1000
comments: false
---

The scripts aren't even cold, and yet here we are. Enter: OSL 2.

<!-- more -->

So, let's get something straight. *Basic* text representation parsing has never been difficult. By this, I mean:

```osl
OSL Script
Text Count|0
Text|Hello, World!
0x33|0, 1, 0, 1
End Script|
```

This is pretty easy to parse - sort of.

You *could* implement a context-dependent version of this without too much difficulty, and you'd be able to call it a day.

However, there's a problem with this. Think back to our V1 Post-Mortem; even with something simple it quickly falls out of control. The game has to be known ahead of time and means that we can't even *validate* whether this code *might* be valid.

We could try doing some regex:

```regexp
(0x([0-9a-fA-F]+)|([a-zA-Z0-9 ]+))\|(\d+(\s*,\s*\d+)*)?(\r?\n)?$
```

^|No highlighting unfortunately because rogue hates fun

However uh... I don't know about you, but that looks complicated as all hell to me, and *not very extendable at all*.

This regex matches lines like `0x33|0, 1, 0, 1`, sure, but at what cost?

Well... you lose a lot of the extensibility of the Open Spiral Language, that's for sure.

One example of this - OSL 2's grammar allows numbers to be defined in binary, octal, decimal, or hex. At first, you can definitely do this with regex:

```regexp
(((0b[0-1]+)|(0o[0-7]+)|(0x[0-9a-fA-F]+)|((?:0d)?[0-9]+))(\s*,\s*((0b[0-1]+)|(0o[0-7]+)|(0x[0-9a-fA-F]+)|((?:0d)?[0-9]+)))*)
```

Just split by the comma, and parse each int and-

I trust you're starting to see the issue.

Regex isn't *bad*, and for highlighting it will be necessary, but here's the beautiful thing - *highlighting* doesn't need all the nuances of parsing.

Highlighting also... let's you break things down to not be behemoths of chaos like our final regex for a basic drill would be:

```regexp
(0x([0-9a-fA-F]+)|([a-zA-Z0-9 ]+))\|(((0b[0-1]+)|(0o[0-7]+)|(0x[0-9a-fA-F]+)|((?:0d)?[0-9]+))(\s*,\s*((0b[0-1]+)|(0o[0-7]+)|(0x[0-9a-fA-F]+)|((?:0d)?[0-9]+)))*)?(\r?\n)?$
```

Omitted in the above regexes (regexes? regii??) are text matching because that's much easier: `(Text|0x01|0x02)\|(.+)(\r?\n)?$` and that's kinda boring.

The use of regex also wouldn't allow us to do anything with variables in any fashion which would make things... confusing.

Can *you* remember which character ID Kazuichi is off the top of your head? What about Sakura?

*What about item IDs?*

OSL 1 solved this in a fairly ambiguous manner - 'basic' drills had to refer to the actual item ID, but individual drills could use a variable mapping of name to numerical ID **or** the numerical ID.

This is awkward for a number of reasons, one of them being that if there wasn't an individual drill for what you wanted, you were sorely out of luck. Also, if it wasn't added yet, or you wanted to store other details, or or or-.

You get the idea.

How does OSL 2 handle this?

`0x33|$stateKeyTimeOfDay, $stateOpSet, 0, $stateValMorning`

By defining an explicit grammar that can reference a variable, we can save a ***lot*** of hassle. This is inline with the goal for OSL 2, which - oh yeah, let's talk about that actually.

## Second Time's The Charm

Starting from scratch has been incredibly helpful for trying to line up exactly how OSL should work. By decoupling verification from parsing (and a step further - separating the parsing from 'tokenisation') the grammar gets much easier to manage.

Let's take the parsing of a basic lin drill. This should match something like `Set Flag|0, 0, 0` or `Set Game Parameter|1, 0, 0, 2`

In Regex:

```regexp
([a-zA-Z0-9 ]+)\|(((0b[0-1]+)|(0o[0-7]+)|(0x[0-9a-fA-F]+)|((?:0d)?[0-9]+))(\s*,\s*((0b[0-1]+)|(0o[0-7]+)|(0x[0-9a-fA-F]+)|((?:0d)?[0-9]+)))*)?(\r?\n)?$
```

In OSL 1:

{% include svgs/osl-1-basic-lin.svg %}

In OSL 2:

{% include svgs/osl-2-basic-lin.svg %}

But wait - what are all those stand-ins in OSL 2's lin code?

Well... the answer *there* is due to how parsing has to work with ANTLR. The rules for tokens are broken up and separate from parser rules.

The components are... relatively simple - in theory. But due to duplication, representing them in a diagram means...

Let's just say it's...

{% inline collapsible.html id='osl-2-basic-lin-full' %}
{% include svgs/osl-2-basic-lin-full.svg %}
{% endinline %}

*not the most fun.*

Now that's not to say that I can't show you *any* of it; the parsing code for values has gotten a bit better:

{% inline collapsible.html id='osl-2-basic-lin-value' %}
{% include svgs/osl-2-basic-lin-value.svg %}
{% endinline %}

This is a very important step back for us to take a step forward; this parsing code can be run *completely independently* from Spiral, technically; a basic ANTLR parser set up with this grammar will be able to verify that our statement is, in fact, valid.

The other important step back is how inter-statement parsing is handled.

---

Remember our example before, about `0x33|$stateKeyTimeOfDay, $stateOpSet, 0, $stateValMorning`?

Let's have a look at how that's parsed through OSL 2.

- `0x33|` matches the rule for a basic lin op code
- `$stateKeyTimeOfDay` matches `BASIC_LIN_VARIABLE_REFERENCE`
- `$stateOpSet` matches `BASIC_LIN_VARIABLE_REFERENCE`
- `0` matches `BASIC_LIN_INTEGER`
- `$stateValMorning` matches `BASIC_LIN_VARIABLE_REFERENCE`

Pretty simple, right? Unambiguous and clear-cut.

What about how the visitor parses it?

This step is done in our programming language of choice, so Java/Kotlin for Spiral:

```kotlin
    override fun visitBasicLinValue(ctx: OpenSpiralParser.BasicLinValueContext): OSLUnion {
        ctx.BASIC_LIN_DOUBLE()?.let { double -> return OSLUnion.NumberType(double.text.toDouble()) }
        ctx.BASIC_LIN_INTEGER()?.let { integer -> return OSLUnion.NumberType(integer.text.toLongVariable()) }
        ctx.BASIC_LIN_VARIABLE_REFERENCE()?.let { varRef -> println("Variable Reference: ${varRef.text.substring(1)}"); return OSLUnion.StringType(varRef.text.substring(1)) }
        ctx.basicLinQuotedString()?.let(this::visit)?.let { return it }

        return OSLUnion.Undefined
    }
```

I realise that the audience for this is not super technical, so allow me to run through it with a fine comb to demonstrate my point.

- `ctx.BASIC_LIN_DOUBLE()?.let { double -> return OSLUnion.NumberType(double.text.toDouble()) }` retrieves the value that matched `BASIC_LIN_DOUBLE`, or null if it didn't match. `?.let { double -> }` runs the block of code only if the value isn't null. This just converts the text to a double, nice and simple.

- `ctx.BASIC_LIN_INTEGER()?.let { integer -> return OSLUnion.NumberType(integer.text.toLongVariable()) }` does a very similar thing, except it's with the `BASIC_LIN_INTEGER` rule, and we call `toLongVariable`. That function simply converts a string to a long, which has a variable base (since it could be binary, octal, hex, or just regular old decimal).

- `ctx.BASIC_LIN_VARIABLE_REFERENCE()?.let { varRef -> println("Variable Reference: ${varRef.text.substring(1)}"); return OSLUnion.StringType(varRef.text.substring(1)) }` is actually filler code; it checks if we matched `BASIC_LIN_VARIABLE_REFERENCE`, and if so prints and returns the variable that we reference (`substring` gets a section of the string after the index, and remember - we start at index 0!).

- `ctx.basicLinQuotedString()?.let(this::visitBasicLinQuotedString)?.let { return it }` is a little more complicated; if we matched `basicLinQuotedString()` with something like `"Hello, World!"`, then we 'visit' the function that handles it, then return it if it isn't null

The visitor model makes these kind of operations much *much* easier to handle at a technical level, and also a hell of a lot more robust[^take-my-word].

Visitors allow us to handle parsing at a token-by-token level, which is perfect for dealing with a complex grammar like OSL can be.

As an unintended side effect, it also allows for type coercion for basic drills; text is *natively handled* by the simple fact that we add a string to the lin file and return the index, it's that simple. Booleans can also be handled easily, since they map to a truthy value we just coerce 'true' as 1, and 'false' as 0.

So hang on, so far this is seeming simple enough[^not-really-simple], what's wrong here? How could I possibly make this more compli-

## Doomed to Repeat

I'm never one to leave things nice and simple. There's always got to be some element of it that's over-engineered to Hell and back; what's OSL 2's?

A new component called Open Spiral Bitcode.

First, let's break down the parsing stages of OSL 2, with an example script:

```osl
OSL Script
val protagonist = "Monokuma"
Text|"Hello, world!"
Makoto: "Hi there!"
$protagonist: "Despair!"
```

There's one big big central problem here - we need to know several values at compile time! Some values, like `Makoto` and `Monokuma` need to be known and available for OSL to be able to transform this into a lin.

This presents a central problem - the script files need to be present in their OSL form if we're going to support compiling to multiple games.

It also means that, inherently, the parsing and compiling stages of OSL are coupled - any OSL parser needs to be able to compile to lin or word scripts, but also needs to be able to import those values! This is, to put it lightly, a bit of overhead that isn't always desirable.

**O**pen **S**piral **B**itcode (OSB) is a component designed to change that. By storing the operations an OSL compiler would in nice easy-to-parse steps, our flow becomes OSL Parser -> OSB Parser -> Lin Compiler, which ends up being much easier to handle and a fair bit more robust.

OSB can be written to or read from in theoretically *any* language without much of a technical difficulty, and allows parsers to be written in any language supported by ANTLR without needing to *also* handle compilation, necessarily.

If you're interested in a more technical writeup of OSB, please check out the [wiki page](https://wiki.spiralframework.info/Open_Spiral_Bitcode).

## A Long Journey

While basic parsing is supported now, there's still a long way to go with OSL. We need to figure out exactly what makes the game 'tick', so to speak, and all the nuances of several opcodes. 

This is an ongoing journey, one that can't be easily summarised in a blog post. If you're interested in helping us out, feel free to join the Spiral Framework Discord server. We'd love to hear from you.

---

[^take-my-word]: For those of you that don't fully understand what I'm talking about at a technical level: You'll just have to take my word for it

[^not-really-simple]: It's not, really, but internally it's a lot cleaner. Trust me.