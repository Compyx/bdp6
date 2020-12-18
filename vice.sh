#/bin/sh

VICE=x64sc-gtk3
PROGRAM=bdp6.prg
# test images
IMAGE9=data/disks/amica_paint_1_8.d64
IMAGE10=data/disks/focusgfx.d64
# scratchpad
IMAGE11=data/disks/bdp6_tests.d64

if [ ! -e $PROGRAM ]; then
    make $PROGRAM
fi


${VICE} \
    -drive9type 1542 -9 "${IMAGE9}" \
    -drive10type 1542 -10 "${IMAGE10}" \
    -drive11type 1542 -11 "${IMAGE11}" \
    -autostartprgmode 1 \
    "${PROGRAM}"

