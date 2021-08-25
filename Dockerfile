# base image
FROM node:14.15.0

# set working directory
RUN mkdir /app
WORKDIR /app

# add `/app/node_modules/.bin` to $PATH
#ENV PATH /app/node_modules/.bin:$PATH

# install and cache app dependencies using yarn
#ADD package.json yarn.lock /app/
#RUN yarn --pure-lockfile

# Copy all frontend stuff to new "app" folder
COPY . /app/

RUN npm install

CMD ["./run.sh"]

EXPOSE 9002


# docker build -t harbor.app.abc.com/library/app:v0.1.0 -f Dockerfile.qa .
# docker push harbor.app.abc.com/library/app:v0.1.0
