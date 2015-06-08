FROM node:0.10

# Cache dependencies
COPY npm-shrinkwrap.json /tmp/npm-shrinkwrap.json
COPY package.json /tmp/package.json
RUN mkdir -p /opt/app && \
    cd /opt/app && \
    cp /tmp/npm-shrinkwrap.json . && \
    cp /tmp/package.json . && \
    npm install --unsafe-perm

COPY . /opt/app

WORKDIR /opt/app

CMD ["npm", "start"]
