---
layout: post
title: Here, again
disqus: true
tags: MSc, 2015
---
I didn't produce any posts for a while. That's because I've worked on my
Master's thesis then studied for my final examination. Fortunately, I've passed
my exam and got a degree with Excellent grade.

I did a lot of Rust development in the last year. The subject of my Master's
thesis was "Design and implementation of efficient, textual data processing
algorithms and correlation methods". I didn't want to fight against segmentation
faults, memory leaks so Rust seemed to be a reasonable choice.

The first some months were hard, as instead of fighting memory leaks I fought
with the borrow checker and lifetimes. I'm here loving Rust so you can guess who
is the winner :) I feel like I learned to program the second time. There is also
an interesting side effect: when I look at some code of an other language, I
search for memory related errors with "thinking in Rust".
# Low level development
I also began to create Rust language bindings for syslog-ng. The goal was to use
my libraries in syslog-ng. I created three crates for this purpose

* syslog-ng-build: contains a function which looks up syslog-ng, links against it
and generates C side module bindings,
* syslog-ng-sys: FFI function and type declarations,
* syslog-ng-common: high level bindings on top of the sys crate.

I've also created a dummy parser implementation which uses these crates: [https://github.com/ihrwein/dummy-parser](https://github.com/ihrwein/dummy-parser).

There is a work in progress blog post about using these crates, I'll cross
post it here.
# Rust development
I've created a log parsing and an event correlation library. The parser library
transforms raw logs into events and the correlation library groups the events
into contexts.

## Log parsing library
The parser library parses logs based on predefines patterns. Yes, I know about
regex. What regex is not good at is performance and maintainability. I borrowed
some concepts from bioinformatics and applied them in my parser. The sheer
throughput of my library was above 1 million parsed logs/sec and I used 500
patterns for the benchmarking. Of course, without any unsafe code. I'd like to
also benchmark the integrated parser.
## Log correlation
Actually, a context is a collection of events. You can execute operations on
contexts when they are opened or closed. This can be useful is you want to
deduplicate your logs:

1. create a pattern for the specific log type
1. transform your raw logs into events with the parser library
1. define a context which collects your logs marked out for deduplication
1. define a context timeout, say 1 minute
1. set a message generation action on context opening and/or closing
1. define your message template

Every action receives information about the state of the context, so you know
how many events are captured, what are their parameters, etc.

# Reading

It took me one year to read all pieces of Robert Jordan's Wheel of time series.
They were very good writings, if you like fantasy you may check them.
