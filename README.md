
### What is this?

Portforwarding via [piping-server](https://github.com/nwtgck/piping-server) inspired by following article.

- [Piping Server を介した双方向パイプによる，任意のネットワークコネクションの確立 \- Qiita](https://qiita.com/Cryolite/items/ed8fa237dd8eab54ef2f)

It is similar to port forwarding by `ssh -L` but source port and target port are connected through following servers.

- portwarp client
- piping-server
- portwarp server

You can run portwarp server in a private network if it is reachable to piping-server via outbound connection.

```
source program -> portwarp client -> piping-server <- portwarp server -> target server
```

### Usage

These examples assumes a piping server available for both client and server side, given as `http://piping.server/`.

server side
```
$ docker run --net=host -ti essa/portwarp portwarp http://piping.server/
I, [2019-03-24T13:36:14.547737 #1]  INFO -- : portwarp start
I, [2019-03-24T13:36:14.547936 #1]  INFO -- : server mode
I, [2019-03-24T13:36:14.589788 #1]  INFO -- : server start url = http://piping.server/29ef18e25dddece9
```

`portwarp` server displays a url for client.
Please give it to client side of `portwarp`.

client side
```
$ git clone https://github.com/essa/portwarp.git
$ cd portwarp
$ bundle
$ bundle exec bin/portwarp http://piping.server/29ef18e25dddece9 8080 private.server.local:80
```

Then `localhost:8080` is connected to `private.server.local:80` and you can connect to it by giving `http://localhost:8080` to your local browser.

Or you can get the response directly by giving a command at the last of command line.

```
$ bundle exec bin/portwarp http://piping.server/29ef18e25dddece9 8080 private.server.local:80 curl http://localhost8080/
```

Other example for client side
```
$ bundle exec bin/portwarp --loglevel=DEBUG http://piping.server/29ef18e25dddece9 1022 localhost:22 ssh -p 1022 ec2-user@localhost
```

### License

MIT

