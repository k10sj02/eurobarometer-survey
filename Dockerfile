FROM --platform=linux/amd64 rocker/verse

WORKDIR /srv/shiny-server

# install only missing packages
RUN R -e "install.packages(c('haven','broom'), repos='https://cloud.r-project.org/')"

# copy everything
COPY . .

# remove default page safely
RUN rm -f /srv/shiny-server/index.html

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]