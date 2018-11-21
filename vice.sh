#/bin/sh

VICE=../vice-trunk/gtk3-build/src/x64sc
PROGRAM=bdp6.prg
# image with a lot of dir entries
IMAGE9=data/disks/amica_paint_1_8.d64
IMAGE10=data/disks/focusgfx.d64
IMAGE11=data/disks/bdp6_tests.d64

if [ ! -e $PROGRAM ]; then
    make $PROGRAM
fi


${VICE} \
    -directory ../alldata \
    -drive9type 1542 -9 "${IMAGE9}" \
    -drive10type 1542 -10 "${IMAGE10}" \
    -drive11type 1542 -11 "${IMAGE11}" \
    -autostartprgmode 1 \
    "${PROGRAM}"

