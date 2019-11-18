---
layout: post
title: "Spiral v3 - Where Are They Now?"
date: 2019-11-18 10:28:00 +1000
comments: false
---

It's been a while since we've touched in with just... regular Spiral stuff. So let's do that, shall we?

<!-- more -->

## Destination Version Despair

Two questions I get asked a lot are "What can Spiral do right now?" and "Which version of Spiral works with what games?".

The unfortunate side effect of naming the versions in the way I did is that some people have been lead to believe that Spiral v2 works with Danganronpa 2, and Spiral v3 works with Danganronpa v3.

So, as of this post going live, Spiral v2 is being "vaulted". While it was already obsolete, it won't receive active support or mention, it will simply be the vaulted version of Spiral. If you need to use it, feel free! I'll always be happy to help people, but when possible the newer versions should be used.

What was "Spiral v3" will now simply be Spiral. I'm not going to try to use a consistent versioning scheme yet since so much is subject to change, but eventually we'll switch over to something like 1.2.3. In time.

## Sea and Features, Creep and Coconuts

So, inevitably, some of you have noticed that the scope of Spiral has grown vastly as time has gone on. What started off as a simple enough toolbox for editing Danganronpa formats has quickly grown into a monolith of features. 

{% include xkcd.html comic=619 comment="*I mean sure, you can't compile wad files properly... but you can track the reaction voice in V3!!*" %}

This presents a number of problems, the easiest to note being that core functionality is missing in favour of more obscure features. How easy is it to change textures around? To write a basic script? What about minigames?

Part of this is the fault of feature creep, but part of it is also the fault of an ever-increasing playing field.

--

Back when Spiral was first started, all the way back in [April of 2016](https://github.com/UnderMybrella/Spiral/commit/33ba55337f03520e8795c828ea3092c1e938a12a), we were only working with *Trigger Happy Havoc*. Shortly after, *Goodbye Despair* was released which left us with two titles that were very very similar.

Fast forward to Ultra Despair Girl's release on Steam, which meant we were working with *three* titles, and then when V3 came out that made *four games* to support - only two of which shared enough similarities to be useful.

The nature of these games has evolved so much that Spiral has had to grow with them, but unlike Spike Chunsoft I am but one person working when I get the chance. 

Spiral has done its best to keep up, but unfortunately the nature of splitting one person among three different game bases is that it just... doesn't work too effectively.

## Trapped by the Ocean Spikes

Moving forward, I'm cutting back on the scope of Spiral temporarily, to try and focus on working with one part at a time, rather than taking on the world all at once.

{% include xkcd.html comic=2138 comment="*As far as I can tell, there are less casualties from Spiral's code than there are developers*" %}

Thus, most of the time and effort will be spent on getting *Danganronpa: Trigger Happy Havoc* in a functional state first. From there, we'll tackle the other games as they come up.

What's currently missing, you might ask?

- [BST](https://wiki.spiralframework.info/wiki/Binary_Spiral_Template) data
- Figuring out the extra data in minigames + documenting
- Figuring out more of the lin opcodes
- Writing a comprehensive GMO parser
- Continued work on [OSL 2](/2019/06/Death-To-OSL)
- (Optionally) tackling SFL files more

The big test that will allow me to move on will be porting a trial over from Danganronpa V3, and seeing how well it all works.

---

This is a relatively small update, just to let everyone know what's happening since I haven't been the best recently. I'll have some new stuff out soon, so stay tuned!