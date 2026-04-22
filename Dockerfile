FROM --platform=linux/amd64 rocker/shiny

WORKDIR /srv/shiny-server

# Install required packages
RUN R -e "install.packages(c('haven','broom','renv'), repos='https://cloud.r-project.org/')"

# Copy EVERYTHING (this is the key fix)
COPY . .

# Restore renv environment (if you're using renv)
RUN R -e "renv::restore()"

# Remove default Shiny page
RUN rm -f /srv/shiny-server/index.html

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]