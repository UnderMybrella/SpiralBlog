---
layout: post
title: "The Secrets We Keep"
date: 2020-10-1 7:10:00 +1000
comments: false
---

It's been over a year since work began on Spiral Triangulum. Let's recap.

<!-- more -->

For those of you who haven't connected your brains to the Spiral Hive Mind, [Spiral Triangulum](https://wiki.spiralframework.info/Version_History#Spiral_-_Triangulum) is the latest version of Spiral, categorised by a long running rewrite since [August Last Year](https://github.com/SpiralFramework/Spiral/commit/b78e071866cf70d3b77dc11d71751dd477955b5a)!

Oh, and it's still not *really* done. Whoops, probably should've lead with that, huh...

Still, let's talk about Spiral, modding in general, and these god-awful games that I have been cursed to work with until I die.

## Back to Basics

So what's the holdup with Triangulum? After all, didn't I write a post [nearly a year ago](/2019/11/Where-Are-They-Now) talking about how it was 'nearly here'?

Yeah... yeah I did... And as we all know, I am nothing if not consistent with my time frames. 

So, what's the hold up?

Excellent question!

At this point, the main hold up with Triangulum is **feature completion**. We've - fortunately - reached the point where spiral-base and spiral-formats are multiplatform supported, and the other modules have all been configured to work with this rewrite. spiral-console is actually compiling and running!

So...?

The problem is that Triangulum currently can only really do three things - it can extract files, it can extract (some) DRv3 textures, and it can extract (most?) DRv3 models.

...

And that's about it.

---

Oh, sorry!! You can also print out the environmental variables.

Obviously, that's the most important feature here.

{% include xkcd.html comic=1361 comment="*I'm shutting down work on Danganronpa to focus on the much more important feature-set - taking up valuable time*" %}

So why is progress so slow?

## Despair in Our Time

Part of the problem is that each feature in Spiral consists of multiple components - a decent name, localised text, good syntax, a lot of error handling... Oh, and the *actual command*.

Let us take the humble file extraction command. In it's most basic form, what does it do? Let's write a quick recipe for it.

- Get archive
- Read archive
- Read list of files from archive
- Get destination
- Write each file to destination from archive

Pretty simple, right? **Wrong**.

Let's throw a few spanners into this real quick:
- What do you do if the file is already there?
- What do you do if the file is compressed?
- What do you do if the file is in an awkward format (see: pak files, tga files, etc)
- What do you do if the archive isn't a valid archive?
- What do you do if the archive doesn't even exist?
- What if the directory doesn't exist?
- How do you support and distinguish between each and every archive type supported by Spiral, without requiring it to be supplied by the end user?[^archive-end-user]

These, and more, are all problems that Spiral has to combat for each command I choose to implement. For instance, a lot of these problems can be solved by prompting the user, like so:

`Error: File exists, would you like to skip or overwrite it (\[S]kip/\[o]verwrite/\[e]nd): `

That works great, except if you have to do that for every single file that already exists, the user is going to be a little frustrated. So there should be a way to say "Hey, do this for all files past this point", which we can do too, but ideally users should be able to pre-emptively tell Spiral what to do in these cases, so it should be able to be supplied.

And I imagine you can start to see the predicament we quickly run into, because this happens for *every* command.

---

Predicament #2 with command design, though - what do you do for multi-input?

If these commands are all designed with singular input in mind, how do you distinguish when, say, a folder is provided? Or multiple files, even? If you have to convert each file manually, that's going to be a real pain, so either we need to provide some natural way to iterate over a folder or list, or we need to support multi-input.

Or both, y'know, but we'll get to that.

{% include xkcd.html comic=741 comment="*Part 2 is rambling for a few hours and hoping people take you seriously*" %}

This is a problem that I do actually have a nice solution for tackling, which is to actually design commands around a neutral interface - any given command has a number of callbacks, but it doesn't *actually* give any output by itself.

This way, singular and multi input both just have to implement the interface in their own way, and all is well in the world.

Do note, though, this is a bit of an undertaking, which is why it's going... so..... slow.......

## Sacrifice Ark

The final big hold up with Triangulum is the games themselves.

Pardon my ego here, but I would say that I'm pretty proficient with these games, and the tools we use to modify them, but even with that in mind it's still an absolute ***pain*** to do even simple edits at times.

Do you want to edit a texture in an event in Dr1? Well, with [Andromeda](https://wiki.spiralframework.info/Version_History#Spiral_-_Andromeda)[^andromeda], you have to:
- Extract the pak file
- (Probably) convert the textures to png files
- Do your edits
- Then, either:
    - Wrap the files up in a zip
    - Pray Spiral converts the textures for you[^ppak]
- Or:
    - Convert the png textures back to tga
    - Wrap the files up in a zip
- Delete the original pak
- Convert the zip back to a pak

Now, I don't know about you, but *that's a lot of work*! And it's incredibly frustrating to have to do *every single damn time you need to make an edit*. It means that speedy edits take multiple steps for a single, simple change.

Obviously, this is far, far, *far* from ideal, so another big part of Triangulum is trying to squish the number of steps you actually need to do.

Take the above workflow, for instance. There's a few neat changes I'm hoping to have implemented, such as the following:
- A workflow command/structure that automagically reruns commands when a file is modified - no more needing to change, save, rerun, etc. Now, just tell Spiral what you want to do, when you want to do it, and it'll make it happen!
- **Treat folders as archives**. This was a big, big failing previously, where you had to wrap the directory to a zip first, and *then* convert it. That's extra work that doesn't serve any purpose, so we should be able to just make it happen by itself.
    - Take the following syntax: `convert archive("directory/path/here") to pak`, which replaces the previous wrap + convert step.
    - But we can go deeper. Take the following command: `convert archive("directory/path/here, transform = "convert {0} from png to tga") to pak`, which replaces the previous convert to tga + wrap + convert.
- Provide 'pipeline' script commands for common tasks. This one's a bit complicated, so let's talk about it.

The 'pipeline' structure is a way of writing your own script commands, so that you can take common tasks and run them multiple times.

Take our directory conversion command from earlier:

`convert archive("directory/path/here, transform = "convert {0} from png to tga") to pak`

This command is going to be run a fair amount, so what if we wrote a custom command to run it, so it's easy to remember?

Since it's a single line, we can actually just use an alias here, which is super easy:

`fnalias flashPak(path: String) -> convert archive(path, transform = "convert {0} from png to tga") to pak`

Now, instead of having to remember that complicated mess of a command, we can just do this:

`flashPak("directory/path/here")`

While we lose the ability to run it without the parenthesis `()`, we've essentially written a custom command!

*This* is what truly lets Triangulum stand out compared to the previous Andromeda version of Spiral - the command parsing is both more robust, and more powerful, while still (hopefully!) being easy to use. 

Unfortunately, it's also one of the things that is causing the most holdup - by the time I get Triangulum out the gates (which, mind you, will hopefully be soon!), I want it to be polished enough to be comfortable to use with actual real-world exploits.

That... does create the problem obviously, of having to find a way to do that.

---

{% include xkcd.html comic=1494 comment="*I'll see you soon*" %}

---

[^archive-end-user]: What this means is that if you pass in an spc archive, Spiral needs to be able to tell it's an spc archive, ideally without you having to explicitly tell it.
[^andromeda]: Also colloquially known as Spiral v2
[^ppak]: This step may be optional, as I *think* Dr1/Dr2 actually do support reading png images from flash archives?