# gost -L redu://1025?tproxy=true -F socks5://:65535 -F socks5://_USER_:_PASS_@1.2.3.4:1080
services:
  - name: service-0
    addr: :1025
    handler:
      type: redu
      chain: chain-0
      metadata:
        tproxy: "true"
    listener:
      type: redu
      metadata:
        tproxy: "true"
    metadata:
      tproxy: "true"
chains:
  - name: chain-0
    hops:
      - name: hop-0
        nodes:
          - name: node-0
            addr: :65535
            connector:
              type: socks5
            dialer:
              type: tcp
      - name: hop-1
        nodes:
          - name: node-0
            dialer:
              type: tcp
              tls:
                serverName: 1.2.3.4
            addr: 1.2.3.4:1080
            connector:
              type: socks5
              auth:
                username: _USER_
                password: _PASS_
