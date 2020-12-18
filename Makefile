# vim: set noet ts=8 sw=8 sts=8 :
#
#

VPATH = src:doc

LABELS = labels.txt
ASM = 64tass
ASM_FLAGS = --ascii --case-sensitive --m6502 --vice-labels --labels $(LABELS) \
	-Wall -Wshadow -Wstrict-bool -I src

TARGET = bdp6.prg

DISKMENU_SOURCES = diskevents.s diskio.s diskmain.s diskutil.s kernal.s

DATA = data/bdp6-grid-sprites.prg data/font.prg
HEADERS = kernal.inc macros.inc
SOURCES = main.s base.s data.s dialogs.s dialog_data.s $(DISKMENU_SOURCES) \
	  edit.s events.s formats.s status.s zoom.s rle.s kernal.s

BDP6_TEST_DISK = data/disks/bdp6-tests.d64
BDP6_TEST_FILES = data/images/hawkeye.bdp6


HTML_FILES = file-formats.html
HTML_STYLE = style.css


%.html: %.md
	pandoc --self-contained -c doc/$(HTML_STYLE) -o doc/$@ $<




all : $(TARGET)

$(TARGET) : $(SOURCES) $(HEADERS) $(DATA)
	$(ASM) $(ASM_FLAGS) -o $@ src/main.s

optimize: $(SOURCES) $(HEADERS) $(DATA)
	$(ASM) $(ASM_FLAGS) -Woptimize -o $(TARGET) src/main.s


$(BDP6_TEST_DISK): $(BDP6_TEST_FILES)




html: $(HTML_FILES)



.PHONY: clean
clean:
	rm -f $(TARGET)
	rm -f $(LABELS)

