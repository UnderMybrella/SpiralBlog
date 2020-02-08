---
layout: post
title: "SpiralBridge Part II; adding a little alcohol to our blend of chaos"
date: 2018-09-11 04:01:57 +1000
comments: false
---

I'd say getting the Windows portion done in less than 10 hours is worthy of a celebration, but apparently my stomach disagrees.

<!--more-->

<br>

*[Previously, on SpiralBridge]({{ site.baseurl }}{% post_url 2018-09-09-SpiralBridge %})*

{% include xkcd.html comic=1722 comment="*I wish I got a cool sword out of that, honestly*" %}

<hr>

It hit me as I was reaching the end of the Windows section for SpiralBridge. 

The fact that I consider getting this done in less than 10 hours says more about me and how nauseating this time allocation is, than it does about the project in question.

Regardless, I managed to get all of what I needed done for Windows done in 9 hours, 46 minutes, and 56 seconds.

On the one hand: much quicker.

On the other...

*sobs.*

<hr>

So, let's get it out of the way. Why did it take so long? All of the framework was there, so all that was needed was the Windows backend, right?

For those of you nerdy enough to check out (and understand) Git/hub, the [commit differences](https://github.com/UnderMybrella/SpiralBridge/commit/a1fde2234b75734fe9626f643d388a616c004e2c#diff-8c3298aa255a95885692c9555af15be0) should prove interesting.

Basically, not much changed for the Synchronisation code itself. I did some cleaning up to handle deallocation now that we're throwing Windows into the mix, but mostly left things untouched.

The main change, however, was with memory regions.

## What's a Memory Region

For those of you who *haven't* spent 50 hours down the rabbit hole that is virtual memory, a memory region is, well... a region of memory.

This is important because it defines the area that programs can put things like variables, and functions, in; all data that needs to be processed tends to make it's way into memory in one fashion or another<sup><sup><sup><sup><sup>well technically not but that's beyond the scope of this, we're simplifying for now</sup></sup></sup></sup></sup>.

Now *unfortunately*, macOS and Windows use different kernels (a kernel is what controls the lower parts of your operating system, sorta. We'll go with that for now...), which means that they have different memory managers.

### What's a Memory Manager?

Let's take a step back and use an analogy for memory. Instead of using all these technical terms, let's imagine we're talking about a library.

In this analogy, the Windows and mach (for macOS) kernels are the libraries themselves. They employ a librarian (memory manager) to keep track of the books (memory addresses, where you can **read** memory ~~please laugh I'm trying my best~~).

{% include xkcd.html comic=1364 comment="*I try my best, but technical analogies aren't always easy, especially when you're dealing with low level programming...*" %}

These books have to be sorted and placed somewhere, and each librarian will come up with different ways for this. In our mach library, you only have a couple of shelves at first, with long rows of books. While there's lots of rows, everything is ordered properly, and while it takes you a while to get the order, once you've figured it out it's consistent.

In Windows, however, you have lots of smaller bookshelves with shorter rows. The librarian here is more than happy to sit down with you and guide you through reading the book, but finding the book is a separate matter. You ask her where to start looking, and she teaches you how to group the bookshelves by their subject, and how each shelf has different properties. You thank her, start looking, and discover that the properties don't mean anything, and sometimes you leave and come back in and they're all changed.

You talk to a few of the other borrowers, and find a few satisfied people, but there's a bit of hush. You're not sure how the bookshelves are ordered; you asked one time and got cut off by the librarian, and when you went back to ask her the shelves had all changed position again. When you decide to just say "fuck it" and look through all of the shelves, it works well until you find a few shelves that actually extend beyond the library and-

*sigh*

Look, this is where the analogy starts to break down; either that, or I do. While mach was difficult to understand at first, once I did it started making sense. Windows has just been painful day in and out; the documentation is nice and all, and it tells me *how* to do what I need, but not *where*.

So with that, let's start from the very beginning, a very good place to start...

## Episode VII: The Kernel Awakens
^> *This actually works better than I expected; both the name and the program*

<br>

I sat down today and told myself I'd get through as much as I could of Windows. And, honestly, I'm proud of myself for the monstrosity I've created.

So let's start with the first thing. I know *what* I need to get, I just need to find out *how* to get it.

Fortunately... I need to do very little. Microsoft's documentation is actually... up to scratch, and covers pretty much everything I needed. That plus stackoverflow and I've got myself some memory regions, woo!

...with one small caveat.

To use our library analogy again, let's say the titles for the books are printed on the spines *only* if the book was published by a proper publisher. If the book has other references that are also in the library (say, for instance, newspaper articles or websites), those have **no** title on the spine, instead.

In fact, there's no double reference there either; nothing to say *what* is referring to our newspaper. So if you find the newspaper, you have no idea what book it's being referenced by.

...

Oh! And the book doesn't actually specify *what* newspaper it references, just that it's referencing *something*. 

Basically, the heap ([where our variable is]({{ site.baseurl }}{% post_url 2018-09-09-SpiralBridge %}#episode-ii-attack-of-the-documentation)) has no name. This wasn't a problem on macOS, because the heap was right after a *named* region. Therefore, we could just take 2 and call up in the morning.

But Kernel32 is a cruel mistress. By allocating lots of small regions all over the place (**most** of the time) in what I can only assume is call order, there's no way to "only" take 2 regions, or to read up to a certain number, or-

-... okay, this has to be dynamic. One moment.

{% include xkcd.html comic=883 comment="*Not gonna lie, Windows put me at a solid 3, today*" %}

<br>

Now, I can't read through every region there is, that would be silly. 

Don't believe me? I had a region that had a supposed space of *over 170* ***GB***. Yeah, gigabytes. Over 170 ***billion*** bytes. 

I wouldn't be able to create an array to hold it all; beyond the fact it would crash every computer it ran on, the JVM only lets you use an integer for array indexing (for good reason, mind you)<sup>[^nb-1]</sup>.

The time it'd take would be insane as well. The tower I use for Windows isn't the best, but it was taking a second or so *per loop*. For safety, that would mean that we need to sleep for *at least* 3 seconds to make sure we get a double pass; and that was only 6 megabytes!

So, I had two initial "ideas":
1. Filter only regions that were either our modules, or blank, and less than a certain threshold, and also readable and writable (both more than acceptable parameters imo)
2. Read the first x regions, or up to a certain region.

It's never that easy, of course, and so neither of these worked.

<br>

The first approach almost made it. ~30% of the time, it worked every time. If Windows was feeling generous, that is.

There were two things that could screw this over. The first: sometimes, Windows would allocate a mega region to Danganronpa (or it would acquire one itself, I'm not sure).

This mega region spanned the size of all our smaller regions, and was "private". Now this meant that it's unique to Danganronpa (good!), ***but*** it also means that the *protections* on it are... "undefined".

So there's no way to tell if the region is actually readable or not, programmatically. Or if it's writable, more importantly.

The second issue? Permissions were not guaranteed for these smaller regions. Sometimes, the address (which was "static" btw, and I'd gotten it via CheatEngine) would fall within a read only region. Sometimes, these regions would be executable. Who knows, honestly. The librarian really likes changing who's allowed to do what to her books.

Needless to say, this approach got me on the right track, but not quite where I needed to be.

<hr>

Second approach - read up until a certain threshold.

I had this idea, and I was looking through the memory regions for some kind of pattern.

*Nothing.* 

Honestly, it was incredibly disheartening. I was prepared to give up with any kind of meaningful solution, maybe turn to C for faster looping? Honestly, I was stumped.

<br>

## Episode VIII: The Last Hack
^> ^> *HAHAHAHA god I wish* <^ <^

<br>

At this point, I've buckled down to doing big loops through the memory. I'm trying to optimise those reads for better speeds, so I'm grouping the regions together to make things as close to seamless as possible.

And this, this is when we hit the Golden Hack. Exactly what I'd been looking for.

A "single" "region" of memory that always (so far) contains the address we need.

To obtain this, I began stitching regions together:

```kotlin
for (i in 0 until viableRegions.size - 1) {
    if (viableRegions[i].start + viableRegions[i].size < viableRegions[i + 1].start) {
        endAddr = viableRegions[i].start + viableRegions[i].size
        break
    }
}
```

And hope for the best, honestly.

This has worked each time so far, and I had a ~~guinea pig~~ friend test it out, with success both times. Persistent through reboots and testing; I'd consider that a success.

So... success?

...

Success... huh...

Well, I've got Windows and macOS working. Linux will probably come soon, but I feel like [something](https://github.com/UnderMybrella/DanganSequence) else [is](https://jenkins.abimon.org/job/DanganSequence) on [the]({{ site.baseurl }}/) horizon...

<hr>

Second writeup's here, and I'm happy with it. I'm still experimenting with style, so apologies if everything is chaotic (I don't know if it'll ever stabilise, honestly). Lemme know how it was/is, hope you enjoyed!

SpiralBridge is available to look at now over [here](http://github.com/UnderMybrella/SpiralBridge), but be careful; She who looks at abominations should be careful lest she thereby become an abomination.

<hr>

[^nb-1]: Yeah, I could have/may use chunking, but that's beside the point honestly.