FROM ruby:2.3.1
EXPOSE 8080
ENV PORT 8080
ADD ./ /webapps
WORKDIR webapps
RUN apt-get update && apt-get install -y nodejs \
                       vim net-tools less tcpdump lsof htop traceroute sysstat mtr rsync man-db
RUN ["bundle", "install"]
ENTRYPOINT ["bundle", "exec"]
CMD ["puma", "-p", "8080", "-w", "2", "-t", "10:50"]
ENV APP_NAME conductor
