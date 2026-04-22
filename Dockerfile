FROM --platform=linux/amd64 rocker/verse:latest

RUN R -e "install.packages(c('haven','broom'), repos='https://cloud.r-project.org/')"

RUN rm -f /srv/shiny-server/index.html

COPY app /srv/shiny-server/app
COPY data /srv/shiny-server/data

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]