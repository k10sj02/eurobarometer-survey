FROM rocker/shiny:latest

RUN R -e "install.packages(c('tidyverse','haven','broom','stringr','ggplot2'), \
  repos='https://cran.rstudio.com/')"

COPY . /srv/shiny-server/

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]