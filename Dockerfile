FROM --platform=linux/amd64 rocker/tidyverse:latest

RUN apt-get update && apt-get install -y \
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  && rm -rf /var/lib/apt/lists/*

# Install packages first — cached unless this line changes
RUN R -e "install.packages(c('shiny','haven','broom'), repos='https://cloud.r-project.org/')"

# Copy code after — changes here won't bust the package cache
COPY . /srv/shiny-server/

RUN rm -f /srv/shiny-server/index.html

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]