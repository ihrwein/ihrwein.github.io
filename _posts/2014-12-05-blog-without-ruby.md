---
layout: post
title: GitHub pages and Docker
date: 2014-12-05 22:00:00
disqus: true
---

You need to install Ruby, Jekyll and a lot of Ruby gems to test your
blog on your machine. With Docker, you can eliminate these
installations and run Jekyll in a fancy Docker container. I think, this
method is far more simple (and elegant) than the manual way to install
all the gems Jekyll needs.

Requirements:

1. a Linux machine with Docker installed,
1. a Docker image containing all Ruby gems installed,
1. `fig` installed on your host.

I found a great [Docker
image](https://registry.hub.docker.com/u/grahamc/jekyll/) but I needed
some more gems to be installed, so I extended it with some
instructions:
{% highlight bash %}
FROM grahamc/jekyll

COPY Gemfile /tmp/
COPY Gemfile.lock /tmp/
RUN cd /tmp && bundle install

ENTRYPOINT ["jekyll"]
{% endhighlight %}

The base image creates a mount point at `/src`, so I can mount the
source code of my site into the container. Accoring to the original
author, we can start the container with the following command:

{% highlight bash %}
$ sudo docker run -d -v "$PWD:/src" -p 4000:4000 grahamc/jekyll serve
{% endhighlight %}

It's a good feature, but we can go deeper and use fig to make it more
comfortable.

Docker's fig can describe your containers in a YAML file, so you don't
have to specify their parameters on every run. My fig.yml looks like
this:

{% highlight yaml %}
jekyll:
    build: .
    volumes:
        - .:/src
    ports:
        - "4000:4000"
    command: serve --watch
{% endhighlight %}

It says, build a Docker image from my Dockerfile, mount the current
directory as /src into the container and create a port binding between
the host and the container.

You have to bootstrap it first:

{% highlight bash %}
$ fig run jekyll build
{% endhighlight %}

Now, you can start your own Jekyll server
with the following command:

{% highlight bash %}
$ fig up
{% endhighlight %}

And that's all :)

## References
* [Fast, isolated development environments using Docker](http://www.fig.sh/index.html)
* [Dockerfile Reference](https://docs.docker.com/reference/builder/)
