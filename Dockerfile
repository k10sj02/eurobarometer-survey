FROM --platform=linux/amd64 rocker/verse

WORKDIR /srv/shiny-server

RUN R -e "install.packages(c('shiny','haven','broom'), repos='https://cloud.r-project.org/')"

COPY . .

RUN rm -f /srv/shiny-server/index.html

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]