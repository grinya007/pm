FROM        perl:latest
MAINTAINER  Gregory Arefyev grinya.guitar@gmail.com

RUN         curl -L http://cpanmin.us | perl - App::cpanminus
RUN         cpanm Carton
RUN         git clone http://github.com/grinya007/pm.git
RUN         cd pm && carton install && carton exec prove

EXPOSE      3000
WORKDIR     pm
CMD         carton exec ./pm.pl prefork -m production -w 4 -c 1
