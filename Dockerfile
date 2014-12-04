FROM ruby:2.1
# from https://github.com/grahamc/docker-jekyll
MAINTAINER graham@grahamc.com

RUN apt-get update \
  && apt-get install -y \
    node \
    python-pygments \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/

RUN gem install \
  github-pages \
  jekyll \
  jekyll-redirect-from \
  kramdown \
  rdiscount \
  rouge

COPY Gemfile /tmp/
COPY Gemfile.lock /tmp/
WORKDIR /tmp
RUN bundle install

VOLUME /src

EXPOSE 4000

WORKDIR /src
ENTRYPOINT ["jekyll"]

