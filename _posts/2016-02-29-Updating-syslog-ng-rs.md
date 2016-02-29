---
layout: post
title: New release of syslog-ng's Rust language bindings
disqus: true
tags: Rust, syslog-ng
---
I was developing a parser plugin for syslog-ng when I realized that I could simplify
the parser interface a little bit.

The `ParserBuilder` trait required to implement the `Clone` trait as well. I removed
this constraint, as it makes the trait more flexible and it was an unnecessary
requirement.

I also added the declaration of the `log_msg_ref()` function to `syslog-ng-sys`
`0.2.2`.

`syslog-ng-common` `0.6.0` contains the updated `ParserBuilder` trait
and a memory leak/crash fix. Your guess is right, the bug was in an `unsafe` block
where I forgot to increment the reference count of a C pointer...
