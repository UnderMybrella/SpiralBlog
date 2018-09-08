---
layout: post
title: "SpiralBridge; a blend of Spiral, Danganronpa, Insanity, and Memory Reading"
date: 2018-09-09 00:20:33 +1000
comments: false
---

*sigh*

<!--more-->

I lost count after 36 hours. 36 hours on one set of features, that no one asked for, and no one really wanted.

Why?

For a shitpost; for the ability to go "Look at what *is* possible".

The result? 

So, so much more than that.

So buckle up, because this is one hell of an adventure.

(*Disclaimer: My primary work environment is macOS High Sierra, so SpiralBridge will currently only work on macOS ~~and Trigger Happy Havoc but we don't talk about that~~. More support coming soon*)

<hr>

## Episode I: The Phantom Address
Right off the bat, we have a big problem. macOS has [ASLR](https://en.wikipedia.org/wiki/Address_space_layout_randomization) (Address Space Layout Randomisation), which prevents us from using static addresses.

ASLR, in laymans terms, means that the operating system changes where things like variables are stored in memory. This prevents nasty exploits from working on protected processes, but also means that we can't do easy things like, say, hardcode the addresses we need.

While ASLR [can be disabled](https://stackoverflow.com/questions/23897963/documented-way-to-disable-aslr-on-os-x), the *[heap](https://www.gribblelab.org/CBootCamp/7_Memory_Stack_vs_Heap.html)* of a program is [still randomised](https://stackoverflow.com/a/18715045).

So problem #1 - we need a form of synchronisation between *Danganronpa* and our game. This shouldn't be too hard, since we control the game scripts that run, after all.

Since 'game state' is our target here, we can use op code [0x33](https://spiralwiki.abimon.org/wiki/0x33) to control a 'game state' variable, and read that, right?

```
OSL Script
Game: DR1

Fade in from black for 0 frames
Music|0, 0, 0

0x33|30, 0, 0, 1 //Change the game state to 1
Wait For Input|
0x33|30, 0, 0, 2 //Change the game state to 2
Wait For Input|
0x33|30, 0, 0, 4 //Change the game state to 4
Wait For Input|
0x33|30, 0, 0, 8 //Change the game state to 8
Wait For Input|
0x33|30, 0, 0, 16 //Change the game state to 16
Wait For Input|

Script|0, 1, 1
Stop Script|
```
<sub>*Since we control the scripts, we control the value of our variables*</sub>

<br>

This looks good on the surface, and works well, but now we hit problem #2 - while we control the variables, we only have so much control over the *timing*.

The script above changes variable 30 to 1, then 2, then 4, then 8, then 16. We wait for the user's input in between each one<sup>[1](#nb-1)</sup>, and if we load up Cheat Engine we can narrow the address down. 

This is great, except for one thing - we don't want the user to have to manually track down the memory address using Cheat Engine, especially since they'd have to do it every time the game starts up.

While we could do something like [pressing the input button for the player](https://docs.oracle.com/javase/10/docs/api/java/awt/Robot.html), this creates a few other issues:
1. We don't know if the user has the game focused. If the user goes off and opens another window, we could interrupt their session with undesired behavior.
2. Our program has no way of actually knowing if the game accepts input. Without some kind of prompt/popup, coupled with screen reading, we would have no way of truly parsing that data.
3. We would take autonomy away from the user in an undesired way.

These problems can be solved with a sleep/delay, however. Fortunately, initial research would seem that we [already have a sleep op code](https://spiralwiki.abimon.org/wiki/0x33#Modes_5_and_6:_Wait).

Coupling this with the fact that most systems will run the game at ~60 fps<sup>[2](#nb-2)</sup>, and we get:

```
OSL Script
Game: DR1

Fade in from black for 0 frames
Music|0, 0, 0

0x33|30, 0, 0, 1 //Change the game state to 1
0x33|5, 0, 0, 120 //Sleep for 2s
0x33|30, 0, 0, 2 //Change the game state to 2
0x33|5, 0, 0, 120 //Sleep for 2s
0x33|30, 0, 0, 4 //Change the game state to 4
0x33|5, 0, 0, 120 //Sleep for 2s
0x33|30, 0, 0, 8 //Change the game state to 8
0x33|5, 0, 0, 120 //Sleep for 2s
0x33|30, 0, 0, 16 //Change the game state to 16
0x33|5, 0, 0, 120 //Sleep for 2s

Script|0, 1, 1
Stop Script|
```
<sub>*I saved this script as "Princess Aurora" internally*</sub>

<br>

Compiling that and running it, yields... less than ideal results.

For some reason, the time waited was inconsistent; sometimes it was 2 seconds, others we barely waited at all.

At this point, I'll be honest I can't remember if I ended up trying out `0x33|6`, but the conclusion was clear - we were getting inconsistencies in the delays, and that was unacceptable for our use case.

Not wanting to deal with more consistency issues<sup>[2](#nb-2)</sup>, I tried out a new solution:

```
OSL Script
Game: DR1

Fade in from black for 0 frames
Music|0, 0, 0

0x33|30, 0, 0, 1 //Change the game state to 1, then sleep for 120 frames (2s)
for (i in 0 until 120) { 
    Wait Frame|
}
0x33|30, 0, 0, 2 //Change the game state to 2, then sleep for 120 frames (2s)
for (i in 0 until 120) { 
    Wait Frame|
}
0x33|30, 0, 0, 4 //Change the game state to 4, then sleep for 120 frames (2s)
for (i in 0 until 120) { 
    Wait Frame|
}
0x33|30, 0, 0, 8 //Change the game state to 8, then sleep for 120 frames (2s)
for (i in 0 until 120) { 
    Wait Frame|
}
0x33|30, 0, 0, 16 //Change the game state to 16, then sleep for 120 frames (2s)
for (i in 0 until 120) { 
    Wait Frame|
}

Script|0, 1, 1
Stop Script|
```
<sub>*The Sleeping Beauty sequel Disney never told you about*</sub>

<br>

This consistently sleeps for 2s on my machine, and gives us a good time frame. But a good time frame for what?

Since we don't have a static address, what we need to do is loop through the memory of our game, and check for those values.

```kotlin
//We loop over every short and store the last value
val candidates = HashMap<Long, Short>()
var memoryAddr = 0
for (i in 0 until size / 2) {
    when (memory.getShort(i * 2)) {
        1 -> {
            if (candidates[i] == 0 || candidates[i] == null) {
                candidates[i] = 1
            } else if (candidates[i] != 1) {
                candidates.remove(i)
            }
        }
        2 -> {
            if (candidates[i] == 1) {
                candidates[i] = 1
            } else if (candidates[i] != 2) {
                candidates.remove(i)
            }
        }
        4 -> {
            if (candidates[i] == 2) {
                candidates[i] = 1
            } else if (candidates[i] != 4) {
                candidates.remove(i)
            }
        }
        8 -> {
            if (candidates[i] == 4) {
                candidates[i] = 1
            } else if (candidates[i] != 8) {
                candidates.remove(i)
            }
        }
        16 -> {
            if (candidates[i] == 8) {
                memoryAddr = i
                break
            } else if (candidates[i] != 16) {
                candidates.remove(i)
            }
        }
    }
}
```
<sub>*If it wasn't obvious, that's 'pseudocode' above. My code is never that clean in practice*</sub>

<br>

Simple, "clean", and easy, right? Well, almost. Reading memory isn't too hard ([ColonelAccess](https://github.com/UnderMybrella/ColonelAccess) to the rescue), but we need to know *where* to read.

<hr>

## Episode II: Attack of the Documentation
<sub>*Yeah the titles don't always work, do they...*</sub>

<br>

So this is where we start descending into platform-specific code, and where my problems start to arise. Because holy shit, where do you begin.

Delving into the deep dark caverns of the internet (I was getting less than 2k results in google for some of these queries) gives us a few things. The first of which proves monumentally helpful - the `vmmap` command on macOS.

This is actually perfect, as with some basic digging this gives us exactly what we need - two writable regions of memory (likely the [stack and heap](https://www.gribblelab.org/CBootCamp/7_Memory_Stack_vs_Heap.html)). Some basic testing with Cheat Engine reveals that our address consistently falls within the *second* region, but we'll parse both of them to be safe.

Now on the one hand, we could end our search here - by parsing the output of `vmmap` we have the data we need, but this is unideal for a number of reasons, the primary one being *portability* . 

`vmmap` is a macOS only application (from what I can tell), and is a command line program. It isn't going to be installed on other operating systems (and would make the implementation of such much more difficult), but it also means that we're relying on *another program* to be there to work, *and* that the output stays consistent.

Now, Apple isn't always the nicest with their toys, and the source code (from what I can tell) for `vmmap` is closed off. However, some digging around lead me to the work of [Julia Evans](https://jvns.ca/blog/2018/01/26/mac-memory-maps/), and her adventure down this path.

This narrowed down very quickly what calls I needed to make; I just needed to make a (few) calls to `mach_vm_region` right?

Well a quick google search gives the [correct Apple kernel page](https://developer.apple.com/documentation/kernel/1402149-mach_vm_region) on their Developer site and...

...well, to save you the trouble of clicking the link, here's what the page shows:

![disappointment 101](/images/mach_vm_region_apple.png)

<sub>*And I thought my documentation was sparse...*</sub>

Okay, so Apple is not gonna be any help here. So, instead, what about the [previously named](https://stackoverflow.com/a/15049937) function, `vm_region`? 

Typing that into Google immediately gets a page from the MIT Darwin documentation, available [here](http://web.mit.edu/darwin/src/modules/xnu/osfmk/man/vm_region.html).

Now this is slightly out of date, true, but with only a few tweaks and using the function declaration available from Apple, I managed to piece my way through some JNA bindings.

This takes... quite some time. With little to no documentation, everything is a 10 minute Google search and 5 minutes of banging my head against a wall whenever things break.

Finally though, after dealing with bizarre errors related to structure size, we get a working commit through with ColonelAccess, that supplies region information. 

We take a separate detour into *Python* of all places ([psutil](https://github.com/giampaolo/psutil/blob/master/psutil/_psutil_osx.c) specifically), and eventually track down the function call to retrieve the "detail" part of our memory map, and we end up with...

A blank region detail, in one of our earlier *Danganronpa* regions. What. The. Hell.

### Episode II.V: JNA Hell
<sub>*Not a funny title this time, just the truth*</sub>

To try and figure out exactly what's going wrong here, I end up jumping down the rabbit hole to debug this.

Fortunately, this system call *is* [open source](https://opensource.apple.com/source/Libc/Libc-498/darwin/libproc.c), so I can look at what exactly it's doing, trace it back and-

...

*...*

If this were easy, anyone could do it.

It takes an hour or two *just* to get the calls right, and once I do, I'm left with the sweet taste of disappointment. A recurring taste, honestly.

Implementing the call, and debugging as far down the track as I can, yields the same thing. A blank detail.

Another hour or two spent searching for *something*, for ***someone*** who has had the same issue... And nothing.

So, time to write some really hacky code to try and work around that, and here we are.

## Episode III: Revenge of the Bear
<sub>*This is about the 20 hour mark btw*</sub>

<br>

Everything is working, and I've made some optimisations to the sleep code. 

Instead of sleeping for a flat 2s, we can sleep instead for a number of frames equal to a benchmark we do earlier;

```kotlin
//We take the maximum time it would take to loop through the memory, and multiply it by 1.5 to be safe
//Then, we multiple that by 5 to simulate 5 loops through memory space, and divide it by the duration of 1 frame

val waitXFrames = ceil(((maxLoopTime * 1.5) * 5) / (TimeUnit.NANOSECONDS.convert(1, TimeUnit.SECONDS) / 60)).toInt()
```
<sub>*Don't worry, this feels worse than it looks*</sub>

<br>

Plugging this all in yields a success. It's beautiful, it works. Synchronisation happens in less than a second, and synchronisation is, most importantly, *reproducible*.

Once again, though... If this were easy, everyone would do it.

We hit our next major issue here -

**Danganronpa crashes.**

![What the fuck](/images/danganronpa_segfault.png)

<sub>*Trust me, I wish I could make this up*</sub>

<br>

We've (somehow) managed to trigger a [Segmentation Fault](https://en.wikipedia.org/wiki/Segmentation_fault) in Danganronpa itself.

That is, we have managed to *remove* memory from *Danganronpa*. Not our own process, *the game itself.*

It's pretty obvious that this is through no fault of Abstraction Games. Between it not being something that would likely slip through, it's reproducible on my end, but only when both what would become SpiralBridge *and* Danganronpa try to fight over memory at the same time.

So, what gives?

Honestly, it's hard to say at first. My initial guess was that some form of memory locking was taking place; Danganronpa would try to access memory that SpiralBridge was reading, and would crash as a result.

Now there's two ways to try and alleviate this, and I tried both.

The first, is to use another function called [`vm_remap`](http://web.mit.edu/darwin/src/modules/xnu/osfmk/man/vm_remap.html) (or [`mach_vm_remap`](https://developer.apple.com/documentation/kernel/1402218-mach_vm_remap) but that's got no documentation).

This allows us to map Danganronpa's memory into our own memory space, so we (should) be able to access it willy nilly without locking-

Nope, still crashing.

Okay, there's a copy parameter, let's try using th-

Nope, still crashing.

<hr>

Okay, take 2.

<hr>

The second attempt we can make is to use [signals](https://en.wikipedia.org/wiki/Signal_(IPC)), to tell Danganronpa to (temporarily) stop processing.

Now this should mean that we can freeze Danganronpa, zip in and grab our memory, then resume processing right?

It's worth noting this slows the game down to a *crawl* - effective framerate of < 10, easily. It stutters the music, the animations, ***everything.***

Now this is *intended*, but not desired, *but*, if it's what is needed, then that's what we'll have to do.

Now we run that, and we do some rebinding, and-

Nope, still crashes.

<hr>

This is a big problem for a few reasons, one of them being it's not exactly *rare*. I'm able to reproduce this under certain conditions, and others not so much. I can't exactly just tell the user "hey your game may crash mid-game, but don't worry about it".

This segfault needs to be taken care of, so let's dig deeper.

<br>

I start pulling out the guts of the reading code (bearing in mind I have to compile this as a JAR file to test; we need `sudo` permissions to run memory code), and we have a closer look.

So it turns out that our code to get the memory region, which returns a `kern_return_t` (or an int, rather), can return one of 6 values:

```kotlin
    KERN_SUCCESS(0),
    KERN_INVALID_ADDRESS(1),
    KERN_PROTECTION_FAILURE(2),
    KERN_NO_SPACE(3),
    KERN_INVALID_ARGUMENT(4),
    KERN_FAILURE(5);
```
<sub>*Guess Colonel Sanders didn't quite make the Top 6*</sub>

This is all handy dandy, but our code returns ***268435459*** when Danganronpa segfaults.

...

Yeah, not sure what's happening there either.

Quick check in Python affirms a suspicion I might have had; `268435459` in hex is `0x10000003`.

So if we use a bitmask to shave off the extra data:

```python
>>> 268435459 & 0x000000FF
3
```

3, which is KERN_NO_SPACE. So we're running out of memory space, at a guess.

I double, triple check that we're deallocating everything, and that memory is being managed as well as it can, rebooting just to make sure.

And still, we're left with nothing. The game closes on startup (the most reliable crash I got), and I'm left in the dust.

I write some code to check region boundaries before we crash, no luck. At this point, it's late, I'm tired. It's been close to 30 hours total, and I call it a night.

## Episode IV: A New Hope
<sub>*Yeah, this one is unchanged, because it's too true.*</sub>

I come back to this mess of a project later that Friday (it's actually proper working hours now), and I sit down and run the game a few more times.

Danganronpa is crashing because it can't access memory. It sometimes crashes on my *benchmarks*, while the game is loading up.

Something isn't right here, but I'm not sure what.

If we trace our steps back, all the way back, there's one other thing we did right before the game started crashing. We started *deallocating* memory.

Now according to [GNU Mach documentation](http://www.gnu.org/software/hurd/gnumach-doc/Data-Transfer.html#Data-Transfer), we should be calling `vm_deallocate` on any data we read. However, *this was proving to be a problem for us*<sup>[3](#nb-3)</sup>.

So, what was the only logical thing to do? Stop deallocating memory<sup>[4](#nb-4)</sup>! The documentation hadn't been updated in 10 years, and my experiences are from `$CURRENT_YEAR`, so let's go with that!

So we stop deallocating memory and...

...I haven't had a crash again to this day.

And that's that! We can synchronise with *Danganronpa*, we have access to the game state, and we can call events from that. Thank you for reading, and I'll see you next time!

<div style="margin-bottom:20em;"></div>

...of course, it's never that easy, is it?

<hr>

## Episode V: Bad Code Strikes Back
<sub>*It was only a matter of time*</sub>

<br>

There are two big issues with this code, two pretty big issues.
1. Memory usage - synchronisation starts chewing up memory *fast*; going from 200 MB to 1.4 *GB* pretty quickly.
2. Synchronisation compilation is *slow*; it can take up to 10s sometimes at best, and needs to be done *each time* a synchronisation is needed. If the user is hasty about getting into their game, they can get in *before* synchronisation is done, and thus ruin the scripts.

At first glance, the solution to 2 somewhat fixes 1; for some reason, the OSL parsing step is actually a bit inefficient for memory usage, and compiling 1k scripts accentuates that. Fortunately, by compiling the script once and making the necessary edits (calling itself again) for each file, we cut down massively; compilation happens in a second or two, and memory usage is minimal.

We still, however, have a massive footprint. This seems to be from a number of places, and some pretty hefty optimisation is needed, with some costs.

As it turns out, using a map and not having a sleep is really bad for Java's Garbage Collector, as it doesn't seem to have time to collect all the extra objects we create to index the map.

These end up stacking up over hundreds of potential iterations, so doing away with the map and using a single array instead saves us some space (an int array and some fancy bit operations does wonders here).

We use a sleep too, to give us some time for the CPU to catch its breath, and we try reading into an array to save on time and memory. None of this proves particularly helpful, however, so more aggressive calls need to be made...

## Episode VI: Return of `vm_remap` 
<sub>*A diamond in the rough*</sub>

<br>

Do you all remember `vm_remap`? The handy little function I mentioned earlier in this document?

It's a very handy function, because it allows us to map a memory space from Danganronpa into our own.

What this means, is that using a regular pointer we can maintain access to the memory *as it updates*. Rather than having a one time window like we normally do with `mach_vm_read`, we can maintain a mirrored window and keep a pointer to that address.

This saves us massive amounts of memory and time; while our code is overall slower than the first iteration, it is now safer and *much* more efficient; SpiralBridge caps at ~250-300 MB of memory from my tests, hasn't crashed yet, and only requires 1 or 2 loops to synchronise, which tends to top out at 2s.

<hr>

## `fin`
<sub>*Holy shit we made it*</sub>

<br>

We did it. We actually made it. Only took us 40 hours or so, but we did it.

Now a big disclaimer here is, is it efficient for memory usage? No, of course not. Not only would a native C version be magnitudes more efficient, it would be faster. However, it would also be more difficult to be cross platform, which is our primary goal here.

In addition, there is the *potential* for memory leaks here, I know. I haven't done tons of tests, so I can't say for sure, but do be warned that memory usage may be a little high.

Can you do anything cool with it? Yeah! I'll have a project showcasing it in the coming days, but for now know that this opens up a tonne of possibilities. We can communicate with an outside script from inside Danganronpa, *and* we can compile scripts and have the game reload those easily.

It's a big step, especially when we thought we were dealing with hardcoded values. It'll be good to see how this goes in the future.

<hr>

And that's that! The first major writeup I've done. I hoped anyone brave enough to read to the end liked it, feel free to come join [our server](/invite) if you haven't already, and lemme know how you felt about this.

SpiralBridge is available to look at now over [here](http://github.com/UnderMybrella/SpiralBridge), gaze at it while you still can.

<hr>

<sup id="nb-1">1</sup> This code may or may not run without the HUD being loaded in.

<sup id="nb-2">2</sup> If your game runs slower than 60 fps (eg: 30), then these delays will take longer. If it runs faster than 60 fps (eg: 120), then these delays will take much less time.

<sup id="nb-3">3</sup> Note that it wasn't *guaranteed* to be the deallocations - there were quite possibly some other things that could be causing it, but this was working for me so... ¯\\\_(ツ)\_/¯

<sup id="nb-4">4</sup> There were a few other under the hood things too, but this was the main one.