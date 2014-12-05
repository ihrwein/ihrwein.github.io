FROM grahamc/jekyll

COPY Gemfile /tmp/
COPY Gemfile.lock /tmp/
RUN cd /tmp && bundle install

ENTRYPOINT ["jekyll"]
