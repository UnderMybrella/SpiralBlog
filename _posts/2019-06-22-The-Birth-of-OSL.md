---
layout: post
title: "The Birth of OSL; Nothing stays dead forever"
date: 2019-06-22 13:01:00 +1000
comments: false
---

The script isn't even cold, and here we are. Enter: OSL 2.

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

{% collapse collapsible.html id='osl-2-basic-lin-full' %}
{% include svgs/osl-2-basic-lin-full.svg %}
{% endcollapse %}

*not the most fun.*

Now that's not to say that I can't show you *any* of it; the parsing code for values has gotten a bit better:

{% collapse collapsible.html id='osl-2-basic-lin-value' %}
{% include svgs/osl-2-basic-lin-value.svg %}
{% endcollapse %}

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

---

[^take-my-word]: For those of you that don't fully understand what I'm talking about at a technical level: You'll just have to take my word for it