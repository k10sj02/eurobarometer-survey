FROM --platform=linux/amd64 rocker/verse

WORKDIR /srv/shiny-server

RUN R -e "install.packages(c('haven','broom'), repos='https://cloud.r-project.org/')"

COPY . .

RUN rm -f /srv/shiny-server/index.html

EXPOSE 3838

CMD ["/bin/bash", "-c", "sed -i \"s/listen 3838;/listen ${PORT};/\" /etc/shiny-server/shiny-server.conf && /usr/bin/shiny-server"]