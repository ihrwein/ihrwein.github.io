---
layout: post
title: Distutils with resource files
date: 2014-12-04 22:00:00
---

I had a little university homework with [Tegi](https://github.com/mTatai) to create a GUI for rsync. We used PyQt5 and Python3 to do

the job and the result can be found [here](https://github.com/ihrwein/yarg). It won't create peace or more cute animgifs, but it's ours and we
could learn some new things from it. One of them was using distutils andresource files together.


I struggled with our `setup.py` until I found a way to
accomplish my goal: I wanted to use resource files (`*.qml`)
in this project and reference them with their relative path to
the project's root directory in my runner script.

You can check the layout of this project:
 * all python files are under `yarg/` package
 * all QML files are under `yarg/resource/`
 * a main program is a script called `runner.py` (in the repo's root dir), which references a QML with path: `yarg/resource/main.qml`

The problem is, that when I install this little program, the runner script ends up
in a `bin` directory somewhere on my computer. It will import the `yarg` package,
but it won't find the `*.qml` files. I worked around this with the following solution:
 * in `setup.py`, I use `data_files` to tell distutils, what are my resource files:
{% highlight python  %}
 data_files=[('resource', ['yarg/resource/main.qml'])],
{% endhighlight %}
 * there is also a `package_data` line, which defines the resources needed by the `yarg` package:
{% highlight python  %}
 package_data={'yarg': ['resource/*']},
{% endhighlight %}
 * the `find_packages()` function is required, because distutils won't copy all Python packages into the ERR,
 * in my runner script, I use the `pkg_resources` module, to access to the resource files
  bundled in a single EGG file, which is a simple compressed file with a specific directory and file
  layout and some meta files. When you use `pkg_resouces`, it will decompress your resources in a temporary
  directory and tells you the location of this place:
{% highlight python%}
  import pkg_resources
  ...
  # This will decompress the whole yarg/resource directory into a temp. dir. and returns
  # the path of that dir.
  # I need this, because my root QML file (main.qml) imports the others next to it.
  pkg_resources.resource_filename('yarg', 'resource')
  ...
  # This function returns the path of the yarg/resource/main.qml files.
  pkg_resources.resource_filename('yarg.resource', 'main.qml')
{% endhighlight %}
And now, I'm able to use the same code in development and after installation. `pkg_resources` will
find the most appropriate locations.
