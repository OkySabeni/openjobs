FROM ruby:2.5.0

LABEL maintainer="oky"

ARG rails_env="development"
ARG build_without=""

RUN apt-get update -yqq \
  && apt-get install -yqq --no-install-recommends \
    postgresql-client \
    nodejs \
    qt5-default \
    libqt5webkit5-dev \
  && apt-get -q clean \
  && rm -rf /var/lib/apt/lists \
  && mkdir -p /var/app

#ENV PATH="$PATH:/opt/yarn/bin" BUNDLE_PATH="/gems" BUNDLE_JOBS=2 RAILS_ENV=${rails_env} BUNDLE_WITHOUT=${bundle_without}

COPY . /var/app
WORKDIR /var/app
COPY Gemfile* ./

##RUN bundle install && yarn && bundle exec rake assets:precompile
RUN bundle install
COPY . .
##CMD rails s -b 0.0.0.0
CMD bundle exec unicorn -c ./config/unicorn.rb
