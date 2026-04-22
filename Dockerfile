FROM --platform=linux/amd64 rocker/shiny:latest

RUN apt-get update && apt-get install -y \
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  libharfbuzz-dev \
  libfribidi-dev \
  libfreetype6-dev \
  libpng-dev \
  libtiff5-dev \
  libjpeg-dev \
  && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('shiny','tidyverse','haven','broom'), repos='https://cloud.r-project.org/')"

COPY . /srv/shiny-server/

RUN rm -f /srv/shiny-server/index.html

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]