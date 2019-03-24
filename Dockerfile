
FROM ruby:slim
ENV PORTWAP_VERSION 0.1.0

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		openssl curl ssh \
	&& rm -rf /var/lib/apt/lists/*


RUN mkdir /app
WORKDIR /app
ADD pkg/ /app/pkg
RUN gem install /app/pkg/portwarp-${PORTWAP_VERSION}.gem
RUN ln -s /usr/local/bundle/gems/portwarp-0.1.0/bin/portwarp /usr/bin/portwarp
