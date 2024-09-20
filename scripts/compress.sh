#!/bin/sh
for i in `ls bin`; do
    sudo setcap cap_net_bind_service=+ep ./bin/$i
    sudo strip ./bin/$i
    sudo upx -f ./bin/$i || true
done 2> /dev/null > /dev/null
