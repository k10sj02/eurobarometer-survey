FROM --platform=linux/amd64 rocker/shiny:latest

RUN R -e "install.packages(c('tidyverse','haven','broom','stringr','ggplot2'), repos='https://cloud.r-project.org/')"

# Remove default landing page (important)
RUN rm /srv/shiny-server/index.html

# Copy app + data
COPY app /srv/shiny-server/app
COPY data /srv/shiny-server/data

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]