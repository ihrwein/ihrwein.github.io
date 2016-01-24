---
layout: post
title: A little refactoring
disqus: true
tags: Rust, generics, refactor
---
I checked the API of the LogMsg struct in my syslog-ng-common crate. Basically,
a LogMsg contains key-value pairs so it behaves like a map. It's API wasn't so
clear as it mirrored the name of the C original C functions.
# Problem

There were three problematic methods:

* `get_value_by_name()`: returns the value assigned to a key
* `get_value()`: returns the value assigned to a handle
* `set_value()`: inserts a new key-value pair

A handle represents an entry in the memory where the value can be directly
accessed. There were some code duplication between the function. For example,
`get_value_by_name()` looked up the handle corresponding to the given key, then
used the handle to get the value, while `get_value_by_name()` took a handle as
its parameter and used that to get the value.

I had only one setter method (`set_value()`) but it's useful to set a value
via a handle.

# Solution

I imagined two functions:
* `get()`: return the value assigned to a key
* `insert()`: insert a new key-value pair

But it'd be nice to have these functions working with handles and string
references as well...

But Rust has generics! So what if we make `get()` generic over types
which implement `Into<NVHandle>`?

```rust
pub fn get<K: Into<NVHandle>>(&self, key: K) -> &str {
    let handle = key.into();
    //...
    let value = logmsg::__log_msg_get_value(self.0, handle.0, &mut size);
    // ...
    value
}
```

We just need to implement it for `&str`:

```rust
impl<'a> Into<NVHandle> for &'a str {
    fn into(self) -> NVHandle {
        let name = CString::new(self).unwrap();
        let handle = unsafe { logmsg::log_msg_get_value_handle(name.as_ptr()) };
        NVHandle(handle)
    }
}
```

This trick can be used for the `insert()` function as well. The API
looks much cleaner and there is no duplicated code.
