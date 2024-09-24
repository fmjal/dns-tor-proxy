#!/bin/sh
for i in `ls bin`; do
    sudo setcap cap_net_bind_service=+ep ./bin/$i
    strip ./bin/$i
    upx -f ./bin/$i || true
    sudo setcap cap_net_bind_service=+ep ./bin/$i || true
done
